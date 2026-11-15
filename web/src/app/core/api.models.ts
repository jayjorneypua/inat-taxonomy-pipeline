// shapes of what the api sends back. property names match the json, which is camelCase

export interface TokenResponse {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface TaxonChildCount {
  id: number;
  scientificName: string;
  commonName: string | null;
  rank: string;
  hasChildren: boolean;
  observationCount: number;
}

export interface TaxonPathItem {
  id: number;
  scientificName: string;
  commonName: string | null;
  rank: string;
  level: number;
}

export interface ObservationMonthCount {
  monthStart: string;
  observationCount: number;
}

export interface ObservationCard {
  observationId: number;
  observationUuid: string;
  observedDate: string;
  taxonId: number;
  scientificName: string;
  commonName: string | null;
  observerDisplayName: string;
  photoCount: number;
  squareUrl: string | null;
  mediumUrl: string | null;
  attribution: string | null;
  license: string | null;
}

export interface ObservationCursor {
  afterObservedDate: string;
  afterObservationId: number;
}

export interface ObservationsPageResponse {
  items: ObservationCard[];
  nextCursor: ObservationCursor | null;
}

export interface ObservationsPageRequest {
  taxonId: number;
  pageSize: number;
  afterObservedDate?: string;
  afterObservationId?: number;
}


export interface GridFilter {
  column: string;
  operator: string;
  value: string;
}

export interface UserGridRequest {
  page: number;
  pageSize: number;
  search: string | null;
  filters: GridFilter[];
  sortColumn: string;
  sortDirection: string;
}

export interface UserGridRow {
  id: number;
  username: string;
  firstName: string;
  lastName: string;
  email: string;
  active: boolean;
  isLocked: boolean;
  loginCount: number;
  lastLoginDate: string | null;
  groupNames: string | null;
  roleNames: string | null;
}

export interface UserGridResponse {
  items: UserGridRow[];
  totalCount: number;
  page: number;
  pageSize: number;
}

export interface CurrentUser {
  id: number;
  username: string;
  firstName: string;
  lastName: string;
  permissions: string[];
}