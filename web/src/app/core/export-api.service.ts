import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpResponse } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ExportJob } from './api.models';

// the export calls: queue one, ask how it is going, download the finished file
@Injectable({ providedIn: 'root' })
export class ExportApiService {
  private readonly http: HttpClient = inject(HttpClient);

  create(taxonId: number): Observable<ExportJob> {
    return this.http.post<ExportJob>('/api/export/create', { taxonId: taxonId });
  }

  getStatus(exportId: number): Observable<ExportJob> {
    return this.http.post<ExportJob>('/api/export/status', { exportId: exportId });
  }

  // the whole response, so the file name the api chose can be read from Content-Disposition
  downloadFile(exportId: number): Observable<HttpResponse<Blob>> {
    return this.http.post('/api/export/file', { exportId: exportId }, { observe: 'response', responseType: 'blob' });
  }
}