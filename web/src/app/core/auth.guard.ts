import { inject } from '@angular/core';
import { CanActivateFn, Router, UrlTree } from '@angular/router';
import { Observable, catchError, map, of } from 'rxjs';
import { AuthService } from './auth.service';

// pages behind this guard need a login. it also loads the current user and their permissions,
// so links and buttons that depend on a permission are right from the first moment
export const authGuard: CanActivateFn = (): Observable<boolean | UrlTree> | UrlTree => {
  const authService: AuthService = inject(AuthService);
  const router: Router = inject(Router);

  if (authService.isLoggedIn() === false) {
    return router.createUrlTree(['/login']);
  }

  return authService.ensureCurrentUser().pipe(
    map((): boolean => true),
    catchError((): Observable<UrlTree> => of(router.createUrlTree(['/login']))),
  );
};

// pages behind this guard also need one permission code, otherwise the user goes back to the explorer.
// ui convenience only: the stored procedures behind the page check the same permission themselves
export function permissionGuard(permissionCode: string): CanActivateFn {
  return (): Observable<boolean | UrlTree> | UrlTree => {
    const authService: AuthService = inject(AuthService);
    const router: Router = inject(Router);

    if (authService.isLoggedIn() === false) {
      return router.createUrlTree(['/login']);
    }

    return authService.ensureCurrentUser().pipe(
      map((): boolean | UrlTree => {
        if (authService.hasPermission(permissionCode)) {
          return true;
        }
        return router.createUrlTree(['/explore']);
      }),
      catchError((): Observable<UrlTree> => of(router.createUrlTree(['/login']))),
    );
  };
}