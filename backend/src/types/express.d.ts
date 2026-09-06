import { UserProfile, AuthUserToken } from './user.types.js';

declare global {
  namespace Express {
    interface Request {
      user?: AuthUserToken;
      profile?: UserProfile;
      token?: string;
    }
  }
}

export {};
