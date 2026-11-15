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