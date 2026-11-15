import { HttpErrorResponse, HttpEvent, HttpHandlerFn, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { Observable, catchError, switchMap, throwError } from 'rxjs';
import { AuthService } from './auth.service';

// these calls must go out without a token and must never trigger a refresh
const UNAUTHENTICATED_URLS: string[] = ['/api/auth/login', '/api/auth/refresh'];

// adds the access token to every api call. on a 401 it tries one refresh and repeats the call once.
// if the refresh fails too, the session is over and the user goes back to the login page
export const authInterceptor: HttpInterceptorFn = (
  request: HttpRequest<unknown>,
  next: HttpHandlerFn,
): Observable<HttpEvent<unknown>> => {
  const authService: AuthService = inject(AuthService);

  if (UNAUTHENTICATED_URLS.includes(request.url)) {
    return next(request);
  }

  return next(withAccessToken(request, authService.accessToken)).pipe(
    catchError((error: unknown): Observable<HttpEvent<unknown>> => {
      const isUnauthorized: boolean = error instanceof HttpErrorResponse && error.status === 401;
      const isLogout: boolean = request.url === '/api/auth/logout';

      if (isUnauthorized === false || isLogout) {
        return throwError((): unknown => error);
      }

      return authService.refresh().pipe(
        switchMap((): Observable<HttpEvent<unknown>> => next(withAccessToken(request, authService.accessToken))),
        catchError((refreshError: unknown): Observable<HttpEvent<unknown>> => {
          authService.clearSession();
          return throwError((): unknown => refreshError);
        }),
      );
    }),
  );
};

function withAccessToken(request: HttpRequest<unknown>, accessToken: string | null): HttpRequest<unknown> {
  if (accessToken === null) {
    return request;
  }

  return request.clone({ setHeaders: { Authorization: `Bearer ${accessToken}` } });
}