define([], function () {
	var configLocal = {};
	// WebAPI
	configLocal.api = {
		name: 'Gen3',
		url: 'https://atlas-qa-mickey.planx-pla.net/WebAPI/'
	};
	configLocal.authProviders = [{
		"name": "Fence",
		"url": "user/login/openid",
		"ajax": false,
		"icon": "fa fa-openid"
	}];
	configLocal.cohortComparisonResultsEnabled = false;
	configLocal.userAuthenticationEnabled = true;
	configLocal.plpResultsEnabled = false;
	return configLocal;
});

var parentOfThisIframe = window.parent;
var mouseoverCount = 0;

console.log("Adding activity event listener...");
window.addEventListener("mouseover", function(event) {
    mouseoverCount++;
    if (mouseoverCount % 20 == 0 && parentOfThisIframe) {
        console.log("Activity detected. Atlas running in an iframe. Posting 'I'm alive' message...");
        parentOfThisIframe.postMessage("refresh token!", "*");
		mouseoverCount = 0;
    }
});
