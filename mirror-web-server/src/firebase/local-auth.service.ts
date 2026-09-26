import { HttpException, Injectable, Logger } from '@nestjs/common'
import { InjectConnection } from '@nestjs/mongoose'
import { randomBytes, scryptSync, timingSafeEqual } from 'crypto'
import * as jwt from 'jsonwebtoken'
import { mongo, Connection } from 'mongoose'

/**
 * Self-hosted replacement for Firebase Authentication.
 *
 * Enabled unless AUTH_PROVIDER=firebase. Users live in the `local_auth_users`
 * MongoDB collection and tokens are HS256 JWTs signed with LOCAL_AUTH_SECRET.
 * It exposes the same methods as FirebaseAuthenticationService (so the rest of
 * the server is unchanged) plus the handful of Identity Toolkit REST calls the
 * Godot client's auth addon makes (see LocalAuthController).
 */

const ID_TOKEN_TTL_SECONDS = 3600
const REFRESH_TOKEN_TTL = '365d'
const ISSUER = 'mirror-local-auth'

export function isLocalAuth(): boolean {
  return (process.env.AUTH_PROVIDER || 'local').toLowerCase() !== 'firebase'
}

interface LocalAuthUser {
  _id: string // same value as uid
  email?: string
  displayName?: string
  passwordHash?: string
  emailVerified: boolean
  disabled: boolean
  createdAt: number
  lastLoginAt?: number
  passwordUpdatedAt?: number
}

/** Mimics a Firebase REST error: HTTP 400 { error: { code, message } } */
export class IdentityToolkitError extends HttpException {
  constructor(message: string) {
    super({ error: { code: 400, message, errors: [{ message }] }, message }, 400)
  }
}

@Injectable()
export class LocalAuthenticationService {
  private readonly logger = new Logger(LocalAuthenticationService.name)
  private readonly secret: string

  constructor(@InjectConnection() private readonly connection: Connection) {
    this.secret = process.env.LOCAL_AUTH_SECRET
    if (!this.secret) {
      this.secret = randomBytes(32).toString('hex')
      this.logger.warn(
        'LOCAL_AUTH_SECRET is not set: using a random secret, so everyone will have to log in again after every server restart.'
      )
    }
  }

  private get users() {
    return this.connection.collection<LocalAuthUser>('local_auth_users')
  }

  // ---------------------------------------------------------------------------
  // FirebaseAuthenticationService-compatible API
  // ---------------------------------------------------------------------------

  async getUser(uid: string) {
    return this.toUserRecord(await this.findByUid(uid))
  }

  async getUserByEmail(email: string) {
    const user = await this.users.findOne({ email: this.normalizeEmail(email) })
    if (!user) {
      throw new IdentityToolkitError('EMAIL_NOT_FOUND')
    }
    return this.toUserRecord(user)
  }

  async createCustomToken(uid: string, additionalClaims?: object) {
    return jwt.sign({ uid, ...additionalClaims, typ: 'custom' }, this.secret, {
      issuer: ISSUER,
      expiresIn: '1h'
    })
  }

  async createUser(properties: {
    uid?: string
    email?: string
    password?: string
    displayName?: string
    emailVerified?: boolean
  }) {
    const uid = properties.uid || new mongo.ObjectId().toHexString()
    const email = properties.email
      ? this.normalizeEmail(properties.email)
      : undefined
    if (email && (await this.users.findOne({ email }))) {
      throw new IdentityToolkitError('EMAIL_EXISTS')
    }
    if (properties.password !== undefined) {
      this.assertPasswordStrength(properties.password)
    }
    const now = Date.now()
    const user: LocalAuthUser = {
      _id: uid,
      email,
      displayName: properties.displayName,
      passwordHash:
        properties.password !== undefined
          ? this.hashPassword(properties.password)
          : undefined,
      emailVerified: properties.emailVerified ?? false,
      disabled: false,
      createdAt: now,
      passwordUpdatedAt: properties.password !== undefined ? now : undefined
    }
    await this.users.insertOne(user)
    return this.toUserRecord(user)
  }

  async updateUser(
    uid: string,
    properties: {
      email?: string
      password?: string
      displayName?: string
      emailVerified?: boolean
      disabled?: boolean
    }
  ) {
    await this.findByUid(uid)
    const update: Partial<LocalAuthUser> = {}
    if (properties.email !== undefined) {
      const email = this.normalizeEmail(properties.email)
      const existing = await this.users.findOne({ email })
      if (existing && existing._id !== uid) {
        throw new IdentityToolkitError('EMAIL_EXISTS')
      }
      update.email = email
    }
    if (properties.password !== undefined) {
      this.assertPasswordStrength(properties.password)
      update.passwordHash = this.hashPassword(properties.password)
      update.passwordUpdatedAt = Date.now()
    }
    if (properties.displayName !== undefined) {
      update.displayName = properties.displayName
    }
    if (properties.emailVerified !== undefined) {
      update.emailVerified = properties.emailVerified
    }
    if (properties.disabled !== undefined) {
      update.disabled = properties.disabled
    }
    await this.users.updateOne({ _id: uid }, { $set: update })
    return this.getUser(uid)
  }

  async deleteUser(uid: string): Promise<void> {
    await this.users.deleteOne({ _id: uid })
  }

  /** Returns claims shaped like a decoded Firebase ID token. */
  async verifyIdToken(idToken: string, _checkRevoked?: boolean) {
    const payload = this.verify(idToken, 'id')
    if (_checkRevoked) {
      const user = await this.users.findOne({ _id: payload.uid })
      if (!user || user.disabled) {
        throw new IdentityToolkitError('USER_DISABLED')
      }
    }
    return payload
  }

  // ---------------------------------------------------------------------------
  // Identity Toolkit REST emulation (used by the Godot client)
  // ---------------------------------------------------------------------------

  async signUp(body: {
    email?: string
    password?: string
    displayName?: string
  }) {
    const isAnonymous = !body.email
    if (!isAnonymous && !body.password) {
      throw new IdentityToolkitError('MISSING_PASSWORD')
    }
    const record = await this.createUser({
      email: body.email,
      password: isAnonymous ? undefined : body.password,
      displayName: body.displayName
    })
    const user = await this.findByUid(record.uid)
    return {
      kind: 'identitytoolkit#SignupNewUserResponse',
      localId: user._id,
      email: user.email || '',
      ...this.issueTokens(user)
    }
  }

  async signInWithPassword(body: { email?: string; password?: string }) {
    const user = await this.users.findOne({
      email: this.normalizeEmail(body.email || '')
    })
    if (!user || !user.passwordHash) {
      throw new IdentityToolkitError('EMAIL_NOT_FOUND')
    }
    if (!this.checkPassword(body.password || '', user.passwordHash)) {
      throw new IdentityToolkitError('INVALID_PASSWORD')
    }
    if (user.disabled) {
      throw new IdentityToolkitError('USER_DISABLED')
    }
    await this.users.updateOne(
      { _id: user._id },
      { $set: { lastLoginAt: Date.now() } }
    )
    return {
      kind: 'identitytoolkit#VerifyPasswordResponse',
      localId: user._id,
      email: user.email,
      displayName: user.displayName || '',
      registered: true,
      ...this.issueTokens(user)
    }
  }

  async signInWithCustomToken(body: { token?: string }) {
    const payload = this.verify(body.token || '', 'custom')
    const user = await this.findByUid(payload.uid)
    return {
      kind: 'identitytoolkit#VerifyCustomTokenResponse',
      isNewUser: false,
      ...this.issueTokens(user)
    }
  }

  async lookup(body: { idToken?: string }) {
    const payload = this.verify(body.idToken || '', 'id')
    const user = await this.findByUid(payload.uid)
    return {
      kind: 'identitytoolkit#GetAccountInfoResponse',
      users: [
        {
          localId: user._id,
          email: user.email || '',
          displayName: user.displayName || '',
          emailVerified: user.emailVerified,
          createdAt: String(user.createdAt),
          lastLoginAt: String(user.lastLoginAt || user.createdAt),
          passwordUpdatedAt: user.passwordUpdatedAt || 0,
          providerUserInfo: []
        }
      ]
    }
  }

  async update(body: {
    idToken?: string
    email?: string
    password?: string
    displayName?: string
  }) {
    const payload = this.verify(body.idToken || '', 'id')
    await this.updateUser(payload.uid, {
      email: body.email,
      password: body.password,
      displayName: body.displayName
    })
    const user = await this.findByUid(payload.uid)
    return {
      kind: 'identitytoolkit#SetAccountInfoResponse',
      localId: user._id,
      email: user.email || '',
      displayName: user.displayName || '',
      ...this.issueTokens(user)
    }
  }

  async deleteAccount(body: { idToken?: string }) {
    const payload = this.verify(body.idToken || '', 'id')
    await this.deleteUser(payload.uid)
    return { kind: 'identitytoolkit#DeleteAccountResponse' }
  }

  /** securetoken.googleapis.com/v1/token */
  async refresh(body: { refresh_token?: string }) {
    const payload = this.verify(body.refresh_token || '', 'refresh')
    const user = await this.findByUid(payload.uid)
    if (user.disabled) {
      throw new IdentityToolkitError('USER_DISABLED')
    }
    const tokens = this.issueTokens(user)
    return {
      access_token: tokens.idToken,
      id_token: tokens.idToken,
      refresh_token: tokens.refreshToken,
      expires_in: tokens.expiresIn,
      token_type: 'Bearer',
      user_id: user._id,
      project_id: 'mirror-local'
    }
  }

  // ---------------------------------------------------------------------------

  private issueTokens(user: LocalAuthUser) {
    const provider = user.passwordHash ? 'password' : 'anonymous'
    const claims = {
      uid: user._id,
      user_id: user._id,
      email: user.email,
      email_verified: user.emailVerified,
      name: user.displayName,
      auth_time: Math.floor(Date.now() / 1000),
      firebase: {
        sign_in_provider: provider,
        identities: user.email ? { email: [user.email] } : {}
      },
      typ: 'id'
    }
    const idToken = jwt.sign(claims, this.secret, {
      issuer: ISSUER,
      audience: 'mirror-local',
      subject: user._id,
      expiresIn: ID_TOKEN_TTL_SECONDS
    })
    const refreshToken = jwt.sign(
      { uid: user._id, typ: 'refresh' },
      this.secret,
      { issuer: ISSUER, expiresIn: REFRESH_TOKEN_TTL }
    )
    return { idToken, refreshToken, expiresIn: String(ID_TOKEN_TTL_SECONDS) }
  }

  private verify(token: string, typ: 'id' | 'refresh' | 'custom'): any {
    let payload: any
    try {
      payload = jwt.verify(token.replace('Bearer ', ''), this.secret, {
        issuer: ISSUER
      })
    } catch (error) {
      throw new IdentityToolkitError(
        typ === 'refresh' ? 'INVALID_REFRESH_TOKEN' : 'INVALID_ID_TOKEN'
      )
    }
    if (payload.typ !== typ || !payload.uid) {
      throw new IdentityToolkitError('INVALID_ID_TOKEN')
    }
    return payload
  }

  private async findByUid(uid: string): Promise<LocalAuthUser> {
    const user = await this.users.findOne({ _id: uid })
    if (!user) {
      throw new IdentityToolkitError('USER_NOT_FOUND')
    }
    return user
  }

  private toUserRecord(user: LocalAuthUser) {
    return {
      uid: user._id,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
      disabled: user.disabled,
      metadata: {
        creationTime: new Date(user.createdAt).toUTCString(),
        lastSignInTime: user.lastLoginAt
          ? new Date(user.lastLoginAt).toUTCString()
          : null
      },
      providerData: []
    }
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase()
  }

  private assertPasswordStrength(password: string) {
    if (password.length < 6) {
      throw new IdentityToolkitError(
        'WEAK_PASSWORD : Password should be at least 6 characters'
      )
    }
  }

  private hashPassword(password: string): string {
    const salt = randomBytes(16)
    const hash = scryptSync(password, salt, 64)
    return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`
  }

  private checkPassword(password: string, stored: string): boolean {
    const [, saltHex, hashHex] = stored.split('$')
    const expected = Buffer.from(hashHex, 'hex')
    const actual = scryptSync(password, Buffer.from(saltHex, 'hex'), 64)
    return timingSafeEqual(expected, actual)
  }
}
