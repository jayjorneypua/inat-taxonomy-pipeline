import { Directive, InputSignal, TemplateRef, ViewContainerRef, effect, inject, input } from '@angular/core';
import { AuthService } from './auth.service';

// shows an element only when the logged in user has a permission code:
//   <a routerLink="/admin/users" *appIfPermission="'admin.users.manage'">Users</a>
// it reacts by itself when the permissions load or change.
// ui convenience only: every stored procedure still checks access itself
@Directive({
  selector: '[appIfPermission]',
})
export class IfPermissionDirective {
  private readonly templateRef: TemplateRef<unknown> = inject(TemplateRef);
  private readonly viewContainer: ViewContainerRef = inject(ViewContainerRef);
  private readonly authService: AuthService = inject(AuthService);

  readonly permissionCode: InputSignal<string> = input.required<string>({ alias: 'appIfPermission' });

  private isShown: boolean = false;

  constructor() {
    effect((): void => {
      const isAllowed: boolean = this.authService.hasPermission(this.permissionCode());

      if (isAllowed && this.isShown === false) {
        this.viewContainer.createEmbeddedView(this.templateRef);
        this.isShown = true;
      } else if (isAllowed === false && this.isShown) {
        this.viewContainer.clear();
        this.isShown = false;
      }
    });
  }
}