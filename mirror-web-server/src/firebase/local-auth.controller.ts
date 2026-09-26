import {
  ArgumentsHost,
  Body,
  Catch,
  Controller,
  ExceptionFilter,
  HttpCode,
  HttpException,
  Param,
  Post,
  UseFilters
} from '@nestjs/common'
import { ApiExcludeController } from '@nestjs/swagger'
import {
  IdentityToolkitError,
  LocalAuthenticationService
} from './local-auth.service'

/** Keeps Firebase's { error: { code, message } } body, which the client parses. */
@Catch()
class IdentityToolkitErrorFilter implements ExceptionFilter {
  catch(exception: Error, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse()
    const body =
      exception instanceof IdentityToolkitError
        ? exception.getResponse()
        : { error: { code: 500, message: exception?.message || 'ERROR' } }
    const status =
      exception instanceof HttpException ? exception.getStatus() : 500
    response.status(status).json(body)
  }
}

/**
 * Serves the Firebase Identity Toolkit / Secure Token REST paths that the
 * Godot client's auth addon calls, so the client can log in against this
 * server instead of Google (see firebase/auth_server_url in the client's env
 * config). Only registered when local auth is enabled.
 */
@ApiExcludeController()
@UseFilters(IdentityToolkitErrorFilter)
@Controller()
export class LocalAuthController {
  constructor(private readonly localAuth: LocalAuthenticationService) {}

  // The client calls e.g. POST /identitytoolkit.googleapis.com/v1/accounts:signUp?key=...
  @Post('identitytoolkit.googleapis.com/v1/:action')
  @HttpCode(200)
  async identityToolkit(@Param('action') action: string, @Body() body: any) {
    switch (action) {
      case 'accounts:signUp':
        return await this.localAuth.signUp(body)
      case 'accounts:signInWithPassword':
        return await this.localAuth.signInWithPassword(body)
      case 'accounts:signInWithCustomToken':
        return await this.localAuth.signInWithCustomToken(body)
      case 'accounts:lookup':
        return await this.localAuth.lookup(body)
      case 'accounts:update':
        return await this.localAuth.update(body)
      case 'accounts:delete':
        return await this.localAuth.deleteAccount(body)
      default:
        // e.g. sendOobCode (verification / password reset emails)
        throw new IdentityToolkitError('OPERATION_NOT_ALLOWED')
    }
  }

  @Post('securetoken.googleapis.com/v1/token')
  @HttpCode(200)
  async token(@Body() body: any) {
    return await this.localAuth.refresh(body)
  }
}
