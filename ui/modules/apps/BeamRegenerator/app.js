angular.module('beamng.apps')
.directive('beamRegenerator', ['CanvasShortcuts', function (CanvasShortcuts) {
  return {
    template:
    '<div style="max-height:100%; width:100%;" layout="row" layout-align="center center" layout-wrap class="bngApp">' +
      '<md-progress-linear md-mode="determinate" flex class="md-accent" style="margin: 2px; min-width: 198px; min-height:16px;" value="{{progress}}" md-no-ink></md-progress-linear>' +
      '<md-button flex style="margin: 2px; min-width: 122px" md-no-ink class="md-raised" ng-click="regenerate()">Repair Vehicle</md-button>' +
      '<md-button flex style="margin: 2px; min-width: 148px" md-no-ink class="md-raised md-warn" ng-click="cancel()">Cancel Repair Job</md-button>' +
      '<md-label flex style="margin: 2px; min-width: 198px">{{status}}</md-label>' +
    '</div>',
    replace: true,
    restrict: 'EA',
    scope: true,
    link: function (scope, element, attrs) {
        scope.progress = 100;
        scope.status = "";
        
        scope.$on('BeamRegeneratorState', function (event, data) {
          var state = data;
          
          if(data.progress < 1 && data.progress > 0.99){
            scope.progress = 99;
          }else{
            scope.progress = data.progress * 100;
          }
          
          scope.status = data.status;
          scope.$apply();
        });
        
        scope.regenerate = function () {
            bngApi.activeObjectLua('extensions.use("beamRegeneration").regenerate()');
        };

        scope.cancel = function () {
            bngApi.activeObjectLua('extensions.use("beamRegeneration").cancelRegenerate()');
            scope.progress = 0;
        }
    }
  }
}]);