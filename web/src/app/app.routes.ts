import { Routes } from '@angular/router';
import { authGuard } from './core/auth.guard';
import { Login } from './pages/login/login';
import { Explorer } from './pages/explorer/explorer';
import { AdminUsers } from './pages/admin-users/admin-users';

export const routes: Routes = [
  { path: 'login', component: Login },
  { path: 'explore', component: Explorer, canActivate: [authGuard] },
  { path: 'explore/:taxonId', component: Explorer, canActivate: [authGuard] },
  { path: 'admin/users', component: AdminUsers, canActivate: [authGuard] },
  { path: '', pathMatch: 'full', redirectTo: 'explore' },
  { path: '**', redirectTo: 'explore' },
];