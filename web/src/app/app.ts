import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

// the shell of the app: every page is shown inside the router outlet
@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {}