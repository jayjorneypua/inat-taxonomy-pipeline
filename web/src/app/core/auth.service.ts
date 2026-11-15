import { Injectable, Signal, WritableSignal, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, finalize, of, shareReplay, tap } from 'rxjs';
import { CurrentUser, TokenResponse } from './api.models';

const ACCESS_TOKEN_KEY: string = 'inat.accessToken';
const REFRESH_TOKEN_KEY: string = 'inat.refreshToken';

// logs in, keeps the tokens, refreshes them, logs out, and knows who is logged in and what they may do.
// tokens live in sessionStorage, so they survive a page reload but not closing the tab
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

  login(username: string, password: string): Observable<TokenResponse> {
    return this.http
      .post<TokenResponse>('/api/auth/login', { username: username, password: password })
      .pipe(
        tap((tokens: TokenResponse): void => {
          this.currentUserSignal.set(null);
          this.storeTokens(tokens);
        }),
      );
  }

  refresh(): Observable<TokenResponse> {
    const refreshToken: string | null = sessionStorage.getItem(REFRESH_TOKEN_KEY);

    return this.http
      .post<TokenResponse>('/api/auth/refresh', { refreshToken: refreshToken })
      .pipe(
        tap((tokens: TokenResponse): void => {
          this.storeTokens(tokens);
          // a refresh rebuilds the session's permissions, so load them again
          this.currentUserSignal.set(null);
          this.ensureCurrentUser().subscribe({ error: (): void => {} });
        }),
      );
  }

  // tells the api to revoke the session, then forgets the tokens whatever the answer
  logout(): void {
    if (this.accessToken !== null) {
      this.http.post('/api/auth/logout', {}).subscribe({ error: (): void => {} });
    }

    this.clearSession();
  }

  // used when the session can't be saved anymore, for example a refresh failed
  clearSession(): void {
    sessionStorage.removeItem(ACCESS_TOKEN_KEY);
    sessionStorage.removeItem(REFRESH_TOKEN_KEY);
    this.accessTokenSignal.set(null);
    this.currentUserSignal.set(null);
    this.pendingCurrentUser = null;
    this.router.navigateByUrl('/login');
  }

  private storeTokens(tokens: TokenResponse): void {
    sessionStorage.setItem(ACCESS_TOKEN_KEY, tokens.accessToken);
    sessionStorage.setItem(REFRESH_TOKEN_KEY, tokens.refreshToken);
    this.accessTokenSignal.set(tokens.accessToken);
  }
}