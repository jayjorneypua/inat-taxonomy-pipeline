import { Component, OnInit, Signal, WritableSignal, computed, inject, signal } from '@angular/core';
import { DatePipe, DecimalPipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Observable, Subject, catchError, debounceTime, map, of, switchMap } from 'rxjs';
import { AdminApiService } from '../../core/admin-api.service';
import { AuthService } from '../../core/auth.service';
import { GridFilter, UserGridRequest, UserGridResponse, UserGridRow } from '../../core/api.models';

// how long to wait after the last keystroke before searching
const SEARCH_DELAY_MILLISECONDS: number = 300;

// one answer from the api: the page, or the message to show when it failed
interface GridLoadResult {
  response: UserGridResponse | null;
  errorMessage: string | null;
}

// the users grid: one search box (name, email, group, role), status chips, sortable columns, page numbers.
// the stored procedure does the actual searching, filtering, sorting and paging
@Component({
  selector: 'app-admin-users',
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe],
  templateUrl: './admin-users.html',
  styleUrl: './admin-users.scss',
})
export class AdminUsers implements OnInit {
  private readonly adminApi: AdminApiService = inject(AdminApiService);
  private readonly authService: AuthService = inject(AuthService);

  // typing goes here, and only reaches the api once the user pauses
  private readonly searchTyping: Subject<void> = new Subject<void>();

  // every request goes here. switchMap cancels an older request when a newer one starts,
  // so a slow old answer can never overwrite a newer one
  private readonly loadRequests: Subject<UserGridRequest> = new Subject<UserGridRequest>();

  readonly pageSizes: number[] = [10, 25, 50, 100];
  readonly statusOptions: string[] = ['Active', 'Inactive', 'Locked'];

  readonly rows: WritableSignal<UserGridRow[]> = signal<UserGridRow[]>([]);
  readonly totalCount: WritableSignal<number> = signal<number>(0);
  readonly page: WritableSignal<number> = signal<number>(1);
  readonly pageSize: WritableSignal<number> = signal<number>(25);
  readonly sortColumn: WritableSignal<string> = signal<string>('Username');
  readonly sortDirection: WritableSignal<string> = signal<string>('asc');
  readonly selectedStatuses: WritableSignal<string[]> = signal<string[]>([]);
  readonly isLoading: WritableSignal<boolean> = signal<boolean>(true);
  readonly errorMessage: WritableSignal<string | null> = signal<string | null>(null);

  searchText: string = '';

  readonly totalPages: Signal<number> = computed((): number => {
    const pages: number = Math.ceil(this.totalCount() / this.pageSize());
    if (pages < 1) {
      return 1;
    }
    return pages;
  });

  constructor() {
    this.searchTyping
      .pipe(debounceTime(SEARCH_DELAY_MILLISECONDS), takeUntilDestroyed())
      .subscribe((): void => this.applyFilters());

    this.loadRequests
      .pipe(
        switchMap(
          (request: UserGridRequest): Observable<GridLoadResult> =>
            this.adminApi.getUsers(request).pipe(
              map((response: UserGridResponse): GridLoadResult => ({ response: response, errorMessage: null })),
              catchError(
                (error: unknown): Observable<GridLoadResult> =>
                  of({ response: null, errorMessage: this.describeError(error) }),
              ),
            ),
        ),
        takeUntilDestroyed(),
      )
      .subscribe((result: GridLoadResult): void => {
        this.isLoading.set(false);

        if (result.response === null) {
          this.errorMessage.set(result.errorMessage);
          return;
        }

        this.rows.set(result.response.items);
        this.totalCount.set(result.response.totalCount);
      });
  }

  ngOnInit(): void {
    this.load();
  }

  onSearchTyped(): void {
    this.searchTyping.next();
  }

  toggleStatus(status: string): void {
    this.selectedStatuses.update((currentStatuses: string[]): string[] => {
      if (currentStatuses.includes(status)) {
        return currentStatuses.filter((currentStatus: string): boolean => currentStatus !== status);
      }
      return [...currentStatuses, status];
    });

    this.applyFilters();
  }

  isStatusSelected(status: string): boolean {
    return this.selectedStatuses().includes(status);
  }

  hasActiveFilters(): boolean {
    return this.searchText.trim() !== '' || this.selectedStatuses().length > 0;
  }

  clearFilters(): void {
    this.searchText = '';
    this.selectedStatuses.set([]);
    this.applyFilters();
  }

  sortBy(column: string): void {
    if (this.sortColumn() === column) {
      if (this.sortDirection() === 'asc') {
        this.sortDirection.set('desc');
      } else {
        this.sortDirection.set('asc');
      }
    } else {
      this.sortColumn.set(column);
      this.sortDirection.set('asc');
    }

    this.page.set(1);
    this.load();
  }

  sortIndicator(column: string): string {
    if (this.sortColumn() !== column) {
      return '';
    }
    if (this.sortDirection() === 'asc') {
      return '▲';
    }
    return '▼';
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages()) {
      return;
    }
    this.page.set(page);
    this.load();
  }

  changePageSize(pageSizeText: string): void {
    this.pageSize.set(Number(pageSizeText));
    this.page.set(1);
    this.load();
  }

  logout(): void {
    this.authService.logout();
  }

  private applyFilters(): void {
    this.page.set(1);
    this.load();
  }

  private load(): void {
    const filters: GridFilter[] = [];

    if (this.selectedStatuses().length > 0) {
      filters.push({ column: 'Status', operator: 'in', value: this.selectedStatuses().join(',') });
    }

    let search: string | null = null;
    if (this.searchText.trim() !== '') {
      search = this.searchText.trim();
    }

    this.isLoading.set(true);
    this.errorMessage.set(null);

    this.loadRequests.next({
      page: this.page(),
      pageSize: this.pageSize(),
      search: search,
      filters: filters,
      sortColumn: this.sortColumn(),
      sortDirection: this.sortDirection(),
    });
  }

  private describeError(error: unknown): string {
    const isForbidden: boolean = error instanceof HttpErrorResponse && error.status === 403;
    if (isForbidden) {
      return 'You do not have permission to manage users.';
    }
    return 'Could not load the users.';
  }
}