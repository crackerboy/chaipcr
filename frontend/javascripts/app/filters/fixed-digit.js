/*
 * Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
 * For more information visit http://www.chaibio.com
 *
 * Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

window.ChaiBioTech.ngApp.filter('fixedDigit', [
  function() {
    return function(value, numDigit) {

      if(isNaN(value)) {
        return "";
      }

      stn = Number(value);
      var data = stn.toExponential().toString().split(/[eE]/);
      var m1 = Number(data[0]);
      var b1 = Number(data[1]);

      if(Math.abs(b1) <= numDigit - 1) {
        if(value.toString().replace('.', '').length > numDigit){
          return Number(value.toString().substring(0, numDigit + 1));
        } else {
          return Number(value);
        }
      }
      return m1.toFixed(2).toString()+"E"+b1.toString();
    };
  }
]);
