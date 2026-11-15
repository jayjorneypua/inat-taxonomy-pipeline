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