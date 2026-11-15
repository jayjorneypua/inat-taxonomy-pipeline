import { Routes } from '@angular/router';
import { authGuard } from './core/auth.guard';
import { Login } from './pages/login/login';
import { Explorer } from './pages/explorer/explorer';

export const routes: Routes = [
  { path: 'login', component: Login },
  { path: 'explore', component: Explorer, canActivate: [authGuard] },
  { path: 'explore/:taxonId', component: Explorer, canActivate: [authGuard] },
  { path: '', pathMatch: 'full', redirectTo: 'explore' },
  { path: '**', redirectTo: 'explore' },
];