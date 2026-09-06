import { Request, Response, NextFunction } from 'express';

type AsyncHandler = (req: Request, res: Response, next: NextFunction) => Promise<any>;

export const asyncWrapper = (fn: AsyncHandler) => {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
};
