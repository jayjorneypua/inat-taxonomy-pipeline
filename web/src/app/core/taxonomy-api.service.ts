import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  ObservationCursor,
  ObservationMonthCount,
  ObservationsPageRequest,
  ObservationsPageResponse,
  TaxonChildCount,
  TaxonPathItem,
} from './api.models';

const PAGE_SIZE: number = 24;

// every call the explorer page makes to the api, in one place
@Injectable({ providedIn: 'root' })
export class TaxonomyApiService {
  private readonly http: HttpClient = inject(HttpClient);

  getPath(taxonId: number): Observable<TaxonPathItem[]> {
    return this.http.post<TaxonPathItem[]>('/api/taxonomy/path', { taxonId: taxonId });
  }

  getChildren(parentTaxonId: number): Observable<TaxonChildCount[]> {
    return this.http.post<TaxonChildCount[]>('/api/dashboard/taxon-children', { parentTaxonId: parentTaxonId });
  }

  getObservationsByMonth(taxonId: number): Observable<ObservationMonthCount[]> {
    return this.http.post<ObservationMonthCount[]>('/api/dashboard/observations-by-month', { taxonId: taxonId });
  }

  // leave the cursor null for the first page
  getObservationsPage(taxonId: number, cursor: ObservationCursor | null): Observable<ObservationsPageResponse> {
    const request: ObservationsPageRequest = { taxonId: taxonId, pageSize: PAGE_SIZE };

    if (cursor !== null) {
      request.afterObservedDate = cursor.afterObservedDate;
      request.afterObservationId = cursor.afterObservationId;
    }

    return this.http.post<ObservationsPageResponse>('/api/taxonomy/observations', request);
  }
}