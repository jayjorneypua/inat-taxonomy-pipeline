import { Injectable, Signal, WritableSignal, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, finalize, of, shareReplay, tap } from 'rxjs';
import { CurrentUser, TokenResponse } from './api.models';

const ACCESS_TOKEN_KEY: string = 'inat.accessToken';

// older versions kept the refresh token here. removed on start so no copy is left behind
const LEGACY_REFRESH_TOKEN_KEY: string = 'inat.refreshToken';

// logs in, keeps the access token, refreshes it, logs out, and knows who is logged in and what they may do.
// the access token (15 minutes) lives in sessionStorage, so it survives a page reload but not closing the tab.
// the refresh token (7 days) lives in an HttpOnly cookie: the browser sends it to /api/auth by itself
// and javascript never sees it, so an xss bug cannot steal it
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http: HttpClient = inject(HttpClient);
  private readonly router: Router = inject(Router);

  private readonly accessTokenSignal: WritableSignal<string | null> = signal<string | null>(
    sessionStorage.getItem(ACCESS_TOKEN_KEY),
  );
  private readonly currentUserSignal: WritableSignal<CurrentUser | null> = signal<CurrentUser | null>(null);

  // one request for the current user at a time, shared by everyone who asks while it runs
  private pendingCurrentUser: Observable<CurrentUser> | null = null;

  readonly isLoggedIn: Signal<boolean> = computed((): boolean => this.accessTokenSignal() !== null);
  readonly currentUser: Signal<CurrentUser | null> = this.currentUserSignal.asReadonly();

  constructor() {
    sessionStorage.removeItem(LEGACY_REFRESH_TOKEN_KEY);
  }

  get accessToken(): string | null {
    return this.accessTokenSignal();
  }

  // ui convenience only: every stored procedure still checks access itself
  hasPermission(permissionCode: string): boolean {
    const currentUser: CurrentUser | null = this.currentUserSignal();
    if (currentUser === null) {
      return false;
    }
    return currentUser.permissions.includes(permissionCode);
  }

  // the current user, loaded from the api the first time it's needed
  ensureCurrentUser(): Observable<CurrentUser> {
    const currentUser: CurrentUser | null = this.currentUserSignal();
    if (currentUser !== null) {
      return of(currentUser);
    }

    if (this.pendingCurrentUser === null) {
      this.pendingCurrentUser = this.http.post<CurrentUser>('/api/auth/me', {}).pipe(
        tap((loadedUser: CurrentUser): void => this.currentUserSignal.set(loadedUser)),
        finalize((): void => {
          this.pendingCurrentUser = null;
        }),
        shareReplay(1),
      );
    }

    return this.pendingCurrentUser;
  }

  // the api answers with the access token and sets the refresh cookie on the same response
  login(username: string, password: string): Observable<TokenResponse> {
    return this.http
      .post<TokenResponse>('/api/auth/login', { username: username, password: password })
      .pipe(
        tap((tokens: TokenResponse): void => {
          this.currentUserSignal.set(null);
          this.storeAccessToken(tokens);
        }),
      );
  }

  // no body: the browser attaches the refresh cookie, and the api answers with a new cookie and access token
  refresh(): Observable<TokenResponse> {
    return this.http
      .post<TokenResponse>('/api/auth/refresh', {})
      .pipe(
        tap((tokens: TokenResponse): void => {
          this.storeAccessToken(tokens);
          // a refresh rebuilds the session's permissions, so load them again
          this.currentUserSignal.set(null);
          this.ensureCurrentUser().subscribe({ error: (): void => {} });
        }),
      );
  }

  // always tells the api, even without an access token, because only the api can remove the HttpOnly cookie.
  // the session is forgotten here whatever the answer
  logout(): void {
    this.http.post('/api/auth/logout', {}).subscribe({ error: (): void => {} });
    this.clearSession();
  }

  // used when the session can't be saved anymore, for example a refresh failed
  clearSession(): void {
    sessionStorage.removeItem(ACCESS_TOKEN_KEY);
    sessionStorage.removeItem(LEGACY_REFRESH_TOKEN_KEY);
    this.accessTokenSignal.set(null);
    this.currentUserSignal.set(null);
    this.pendingCurrentUser = null;
    this.router.navigateByUrl('/login');
  }

  private storeAccessToken(tokens: TokenResponse): void {
    sessionStorage.setItem(ACCESS_TOKEN_KEY, tokens.accessToken);
    this.accessTokenSignal.set(tokens.accessToken);
  }
}