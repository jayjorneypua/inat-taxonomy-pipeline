import { Component, DestroyRef, Signal, WritableSignal, computed, inject, signal } from '@angular/core';
import { DatePipe, DecimalPipe } from '@angular/common';
import { HttpResponse } from '@angular/common/http';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, ParamMap, RouterLink } from '@angular/router';
import { Observable, switchMap, takeWhile, timer } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { ExportApiService } from '../../core/export-api.service';
import { IfPermissionDirective } from '../../core/if-permission.directive';
import { TaxonomyApiService } from '../../core/taxonomy-api.service';
import {
  ExportJob,
  ObservationCard,
  ObservationCursor,
  ObservationMonthCount,
  ObservationsPageResponse,
  TaxonChildCount,
  TaxonPathItem,
} from '../../core/api.models';

const ROOT_TAXON_ID: number = 48460;
const EXPORT_POLL_MILLISECONDS: number = 1000;

// one taxon at a time: its breadcrumb, its children, its monthly chart and its photos.
// the taxon comes from the url, so every page can be bookmarked and the back button works
@Component({
  selector: 'app-explorer',
  imports: [RouterLink, DecimalPipe, DatePipe, IfPermissionDirective],
  templateUrl: './explorer.html',
  styleUrl: './explorer.scss',
})
export class Explorer {
  private readonly route: ActivatedRoute = inject(ActivatedRoute);
  private readonly taxonomyApi: TaxonomyApiService = inject(TaxonomyApiService);
  private readonly exportApi: ExportApiService = inject(ExportApiService);
  private readonly authService: AuthService = inject(AuthService);
  private readonly destroyRef: DestroyRef = inject(DestroyRef);

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

  readonly isExporting: WritableSignal<boolean> = signal<boolean>(false);
  readonly exportMessage: WritableSignal<string | null> = signal<string | null>(null);
  readonly exportError: WritableSignal<string | null> = signal<string | null>(null);

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

  // queues the export, asks every second how it is going, and saves the file when it is done
  exportObservations(): void {
    if (this.isExporting()) {
      return;
    }

    const taxonId: number = this.taxonId();
    this.isExporting.set(true);
    this.exportError.set(null);
    this.exportMessage.set('Export queued...');

    this.exportApi
      .create(taxonId)
      .pipe(
        switchMap((createdJob: ExportJob): Observable<ExportJob> =>
          timer(0, EXPORT_POLL_MILLISECONDS).pipe(
            switchMap((): Observable<ExportJob> => this.exportApi.getStatus(createdJob.id)),
            takeWhile((job: ExportJob): boolean => job.status === 'Queued' || job.status === 'Running', true),
          ),
        ),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe({
        next: (job: ExportJob): void => this.handleExportStatus(job),
        error: (): void => {
          this.isExporting.set(false);
          this.exportMessage.set(null);
          this.exportError.set('Could not export. Please try again.');
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

  private handleExportStatus(job: ExportJob): void {
    if (job.status === 'Done') {
      this.exportMessage.set('Downloading...');
      this.downloadExport(job);
      return;
    }

    if (job.status === 'Failed') {
      this.isExporting.set(false);
      this.exportMessage.set(null);
      this.exportError.set(job.errorMessage ?? 'Export failed.');
      return;
    }

    this.exportMessage.set(`Export ${job.status.toLowerCase()}...`);
  }

  private downloadExport(job: ExportJob): void {
    this.exportApi.downloadFile(job.id).subscribe({
      next: (response: HttpResponse<Blob>): void => {
        const body: Blob | null = response.body;
        if (body === null) {
          this.isExporting.set(false);
          this.exportMessage.set(null);
          this.exportError.set('The export file was empty.');
          return;
        }

        const fileName: string = this.fileNameFromResponse(response, job.id);
        const url: string = URL.createObjectURL(body);
        const link: HTMLAnchorElement = document.createElement('a');
        link.href = url;
        link.download = fileName;
        link.click();
        setTimeout((): void => URL.revokeObjectURL(url), 1000);

        this.isExporting.set(false);
        this.exportMessage.set(`Downloaded ${fileName} (${job.rowCount ?? 0} rows).`);
      },
      error: (): void => {
        this.isExporting.set(false);
        this.exportMessage.set(null);
        this.exportError.set('Could not download the export.');
      },
    });
  }

  // the api (spExport_GetFile) decides the file name and sends it in Content-Disposition
  private fileNameFromResponse(response: HttpResponse<Blob>, exportId: number): string {
    const disposition: string | null = response.headers.get('Content-Disposition');
    if (disposition !== null) {
      const match: RegExpMatchArray | null = disposition.match(/filename="?([^";]+)"?/i);
      if (match !== null) {
        return match[1];
      }
    }
    return `export-${exportId}.csv`;
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