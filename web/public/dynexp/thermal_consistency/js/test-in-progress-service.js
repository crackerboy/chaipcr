window.App.service('TestInProgressService', [
  '$rootScope',
  'Experiment',
  '$q',
  'Status',
  function($rootScope, Experiment, $q, Status) {
    var directivesCount, experiment, experimentQues, holding, isFetchingExp, status;
    directivesCount = 0;
    status = null;
    experiment = null;
    holding = false;
    experimentQues = {};
    isFetchingExp = false;

    this.getMaxDeltaTm = function (tms) {
      var min_tm = Math.min.apply(Math, tms);
      var max_tm = Math.max.apply(Math, tms);
      return max_tm - min_tm;
    };

    this.getTmValues = function (analyze_data) {
      console.log("This is analyze_data", analyze_data);
      var tms = [];
      for (var i=0; i< 16; i++) {
        if(analyze_data.mc_out['fluo_'+i].tm.length > 0) {
          console.log("inside loop", i, analyze_data.mc_out['fluo_'+i]);
          tms.push(analyze_data.mc_out['fluo_'+i].tm[0].Tm);
        }
      }
      return tms;
    };

    this.is_holding = function() {
      return holding;
    };
    this.set_holding = function(data, experiment) {
      var duration, stages, state, steps;
      if (!experiment) {
        return false;
      }
      if (!experiment.protocol) {
        return false;
      }
      if (!experiment.protocol.stages) {
        return false;
      }
      if (!data) {
        return false;
      }
      if (!data.experiment_controller) {
        return false;
      }
      stages = experiment.protocol.stages;
      steps = stages[stages.length - 1].stage.steps;
      duration = parseInt(steps[steps.length - 1].step.delta_duration_s);
      state = data.experiment_controller.machine.state;
      holding = state === 'complete' && duration === 0;
      return holding;
    };

    this.getExperiment = function(id) {
      var deferred, fetchPromise;
      deferred = $q.defer();
      experimentQues["exp_id_" + id] = experimentQues["exp_id_" + id] || [];
      experimentQues["exp_id_" + id].push(deferred);
      if (!isFetchingExp) {
        isFetchingExp = true;
        fetchPromise = Experiment.get({
          id: id
        }).$promise;
        fetchPromise.then((function(_this) {
          return function(resp) {
            var def, i, len, ref, results;
            _this.set_holding(status, experiment);
            experimentQues["exp_id_" + resp.experiment.id] = experimentQues["exp_id_" + resp.experiment.id] || [];
            ref = experimentQues["exp_id_" + resp.experiment.id];
            results = [];
            for (i = 0, len = ref.length; i < len; i += 1) {
              def = ref[i];
              experiment = resp.experiment;
              results.push(def.resolve(experiment));
            }
            return results;
          };
        })(this));
        fetchPromise["catch"](function(err) {
          var def, i, len, results;
          results = [];
          for (i = 0, len = experimentQues.length; i < len; i += 1) {
            def = experimentQues[i];
            def.reject(err);
            results.push(experiment = null);
          }
          return results;
        });
        fetchPromise["finally"](function() {
          isFetchingExp = false;
          return experimentQues["exp_id_" + id] = [];
        });
      }
      return deferred.promise;
    };
    this.timeRemaining = function(data) {
      var exp, time;
      if (!data) {
        return 0;
      }
      if (!data.experiment_controller) {
        return 0;
      }
      if (data.experiment_controller.machine.state === 'running') {
        exp = data.experiment_controller.expriment;
        time = (exp.estimated_duration * 1 + exp.paused_duration * 1) - exp.run_duration * 1;
        if (time < 0) {
          time = 0;
        }
        return time;
      } else {
        return 0;
      }
    };
    this.getExperimentSteps = function (exp) {
      var stages = exp.protocol.stages;
      var steps = [];

      for (var i=0; i < stages.length; i++) {
        var stage = stages[i].stage;
        var _steps = stage.steps;

        for (var ii=0; ii < _steps.length; ii ++) {
          steps.push(_steps[ii].step);
        }
      }
      return steps;
    };
  }
]);

// ---
// generated by coffee-script 1.9.2
