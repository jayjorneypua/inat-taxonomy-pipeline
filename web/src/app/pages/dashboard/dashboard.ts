import { Component, OnInit, WritableSignal, inject, signal } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../../core/auth.service';
import { TaxonChildCount } from '../../core/api.models';

// first version of the dashboard: the kingdoms under Life with their observation counts
@Component({
  selector: 'app-dashboard',
  imports: [DecimalPipe],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
})
export class Dashboard implements OnInit {
  private readonly http: HttpClient = inject(HttpClient);
  private readonly authService: AuthService = inject(AuthService);

  readonly kingdoms: WritableSignal<TaxonChildCount[]> = signal<TaxonChildCount[]>([]);
  readonly isLoading: WritableSignal<boolean> = signal<boolean>(true);
  readonly errorMessage: WritableSignal<string | null> = signal<string | null>(null);

  ngOnInit(): void {
    this.http.post<TaxonChildCount[]>('/api/dashboard/taxon-children', {}).subscribe({
      next: (rows: TaxonChildCount[]): void => {
        this.kingdoms.set(rows);
        this.isLoading.set(false);
      },
      error: (): void => {
        this.errorMessage.set('Could not load the data.');
        this.isLoading.set(false);
      },
    });
  }

  logout(): void {
    this.authService.logout();
  }
}