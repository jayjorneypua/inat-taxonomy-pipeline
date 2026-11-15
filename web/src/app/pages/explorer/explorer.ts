import { Component, Signal, WritableSignal, computed, inject, signal } from '@angular/core';
import { DatePipe, DecimalPipe } from '@angular/common';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, ParamMap, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { TaxonomyApiService } from '../../core/taxonomy-api.service';
import {
  ObservationCard,
  ObservationCursor,
  ObservationMonthCount,
  ObservationsPageResponse,
  TaxonChildCount,
  TaxonPathItem,
} from '../../core/api.models';

const ROOT_TAXON_ID: number = 48460;

// one taxon at a time: its breadcrumb, its children, its monthly chart and its photos.
// the taxon comes from the url, so every page can be bookmarked and the back button works
@Component({
  selector: 'app-explorer',
  imports: [RouterLink, DecimalPipe, DatePipe],
  templateUrl: './explorer.html',
  styleUrl: './explorer.scss',
})
export class Explorer {
  private readonly route: ActivatedRoute = inject(ActivatedRoute);
  private readonly taxonomyApi: TaxonomyApiService = inject(TaxonomyApiService);
  private readonly authService: AuthService = inject(AuthService);

  readonly taxonId: WritableSignal<number> = signal<number>(ROOT_TAXON_ID);
  readonly path: WritableSignal<TaxonPathItem[]> = signal<TaxonPathItem[]>([]);
  readonly children: WritableSignal<TaxonChildCount[]> = signal<TaxonChildCount[]>([]);
  readonly monthCounts: WritableSignal<ObservationMonthCount[]> = signal<ObservationMonthCount[]>([]);
  readonly observations: WritableSignal<ObservationCard[]> = signal<ObservationCard[]>([]);
  readonly nextCursor: WritableSignal<ObservationCursor | null> = signal<ObservationCursor | null>(null);

  readonly isLoadingChildren: WritableSignal<boolean> = signal<boolean>(true);
  readonly isLoadingObservations: WritableSignal<boolean> = signal<boolean>(true);
  readonly isLoadingMore: WritableSignal<boolean> = signal<boolean>(false);
  readonly errorMessage: WritableSignal<string | null> = signal<string | null>(null);

  readonly currentTaxon: Signal<TaxonPathItem | null> = computed((): TaxonPathItem | null => {
    const pathItems: TaxonPathItem[] = this.path();
    if (pathItems.length === 0) {
      return null;
    }
    return pathItems[pathItems.length - 1];
  });

  readonly maximumMonthCount: Signal<number> = computed((): number => {
    let maximum: number = 0;
    for (const monthCount of this.monthCounts()) {
      if (monthCount.observationCount > maximum) {
        maximum = monthCount.observationCount;
      }
    }
    return maximum;
  });

  constructor() {
    this.route.paramMap.pipe(takeUntilDestroyed()).subscribe((parameters: ParamMap): void => {
      const taxonIdText: string | null = parameters.get('taxonId');
      let taxonId: number = ROOT_TAXON_ID;

      if (taxonIdText !== null && Number.isInteger(Number(taxonIdText))) {
        taxonId = Number(taxonIdText);
      }

      this.loadTaxon(taxonId);
    });
  }

  loadMore(): void {
    const cursor: ObservationCursor | null = this.nextCursor();
    if (cursor === null) {
      return;
    }

    const taxonId: number = this.taxonId();
    this.isLoadingMore.set(true);

    this.taxonomyApi.getObservationsPage(taxonId, cursor).subscribe({
      next: (page: ObservationsPageResponse): void => {
        // ignore answers for a taxon the user already left
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.observations.update((existingCards: ObservationCard[]): ObservationCard[] => [...existingCards, ...page.items]);
        this.nextCursor.set(page.nextCursor);
        this.isLoadingMore.set(false);
      },
      error: (): void => {
        this.isLoadingMore.set(false);
        this.errorMessage.set('Could not load more photos.');
      },
    });
  }

  barHeightPercent(observationCount: number): number {
    const maximum: number = this.maximumMonthCount();
    if (maximum === 0) {
      return 0;
    }
    return (observationCount / maximum) * 100;
  }

  isJanuary(monthStart: string): boolean {
    return monthStart.substring(5, 7) === '01';
  }

  logout(): void {
    this.authService.logout();
  }

  private loadTaxon(taxonId: number): void {
    this.taxonId.set(taxonId);
    this.path.set([]);
    this.children.set([]);
    this.monthCounts.set([]);
    this.observations.set([]);
    this.nextCursor.set(null);
    this.errorMessage.set(null);
    this.isLoadingChildren.set(true);
    this.isLoadingObservations.set(true);

    this.taxonomyApi.getPath(taxonId).subscribe({
      next: (pathItems: TaxonPathItem[]): void => {
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.path.set(pathItems);
        if (pathItems.length === 0) {
          this.errorMessage.set('This taxon does not exist or is outside your access.');
        }
      },
      error: (): void => this.errorMessage.set('Could not load this taxon.'),
    });

    this.taxonomyApi.getChildren(taxonId).subscribe({
      next: (rows: TaxonChildCount[]): void => {
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.children.set(rows);
        this.isLoadingChildren.set(false);
      },
      error: (): void => this.isLoadingChildren.set(false),
    });

    this.taxonomyApi.getObservationsByMonth(taxonId).subscribe({
      next: (rows: ObservationMonthCount[]): void => {
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.monthCounts.set(rows);
      },
    });

      this.taxonomyApi.getObservationsPage(taxonId, null).subscribe({
      next: (page: ObservationsPageResponse): void => {
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.observations.set(page.items);
        this.nextCursor.set(page.nextCursor);
        this.isLoadingObservations.set(false);
      },
      error: (): void => {
        if (this.taxonId() !== taxonId) {
          return;
        }
        this.isLoadingObservations.set(false);
        this.errorMessage.set('Could not load the photos. Please try again.');
      },
    });
  }
}