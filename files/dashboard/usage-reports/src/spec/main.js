import './dataHelperSpec.js';
import './datePickerSpec.js';
import './reportsTableSpec.js';
import './windowSizerSpec.js';


if (typeof gen3StartJasmine === 'function') {
  gen3StartJasmine();
} else {
  console.log('No gen3StartJasmine boot function - assuming karmajs environment');
}
