import { TestBed, async, inject } from '@angular/core/testing';
import { RouterTestingModule } from '@angular/router/testing';

import { SharedModule } from '../shared/shared.module';
import { DashboardRoutingModule } from './dashboard.routing.module';
import { DashboardComponent } from './dashboard.component';
import { HomeModule } from './home/home.module';

import { StatusService } from '../shared/services/status/status.service'
import { ExperimentService } from '../shared/services/experiment/experiment.service'

const mockExperimentService = {
  getExperiments: () => {
    return {
      subscribe: (cb) => {
        cb([])
      }
    }
  }
}

describe('DashboardComponent', () => {
  beforeEach(async(() => {

    TestBed.configureTestingModule({
      imports: [
        RouterTestingModule,
        SharedModule,
        DashboardRoutingModule,
        HomeModule,
      ],
      declarations: [
        DashboardComponent
      ]
    }).compileComponents();

  }));

  it('should create the app', () => {
    const fixture = TestBed.createComponent(DashboardComponent);
    const app = fixture.debugElement.componentInstance;
    expect(app).toBeTruthy();
    const compiled = fixture.debugElement.nativeElement;
    expect(compiled.querySelector('router-outlet')).toBeTruthy();
  });

  it('should call statusService.startSync()', inject(
    [StatusService],
    (statusService: StatusService) => {
      spyOn(statusService, 'startSync')
      const fixture = TestBed.createComponent(DashboardComponent)
      expect(statusService.startSync).toHaveBeenCalled()
    }
  ))

});
