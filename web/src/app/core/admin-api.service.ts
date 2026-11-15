import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { UserGridRequest, UserGridResponse } from './api.models';

// every call the admin pages make to the api, in one place
@Injectable({ providedIn: 'root' })
export class AdminApiService {
  private readonly http: HttpClient = inject(HttpClient);

  getUsers(request: UserGridRequest): Observable<UserGridResponse> {
    return this.http.post<UserGridResponse>('/api/admin/users/grid', request);
  }
}