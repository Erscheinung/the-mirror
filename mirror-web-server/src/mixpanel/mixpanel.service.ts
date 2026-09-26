import * as mixpanelLib from 'mixpanel'
import { Injectable } from '@nestjs/common'
require('dotenv').config()

// Analytics are optional (self-hosted servers usually have no token)
const mixpanel = process.env.MIXPANEL_TOKEN
  ? mixpanelLib.init(process.env.MIXPANEL_TOKEN, { keepAlive: false })
  : undefined

@Injectable()
export class MixpanelService {}
