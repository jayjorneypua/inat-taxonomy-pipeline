import { Component, WritableSignal, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';

@Component({
  selector: 'app-login',
  imports: [FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.scss',
})
export class Login {
  private readonly authService: AuthService = inject(AuthService);
  private readonly router: Router = inject(Router);

  username: string = '';
  password: string = '';

  readonly errorMessage: WritableSignal<string | null> = signal<string | null>(null);
  readonly isSubmitting: WritableSignal<boolean> = signal<boolean>(false);

  submit(): void {
    const trimmedUsername: string = this.username.trim();

    if (trimmedUsername === '' || this.password === '') {
      this.errorMessage.set('Enter your username and password.');
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);

    this.authService.login(trimmedUsername, this.password).subscribe({
      next: (): void => {
        this.isSubmitting.set(false);
        this.router.navigateByUrl('/dashboard');
      },
      error: (): void => {
        this.password = '';
        this.isSubmitting.set(false);
        this.errorMessage.set('Invalid username or password.');
      },
    });
  }
}