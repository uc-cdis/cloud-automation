/* eslint-disable */
$(() => {
    String.prototype.insert = function (index, string) {
      if (index > 0)
        return this.substring(0, index) + string + this.substring(index, this.length);
      
      return string + this;
    };

    fetch("https://qa.planx-pla.net/dashboard/Secure/QA/").then(
	(r) => r.json()
    ).then(
	(files) => {
	    const monthsDigitToString = [ "January", "February", "March", "April", "May", "June", 
					  "July", "August", "September", "October", "November", "December" ];
            let reports = {};
	    files.forEach((file) => {
		const fileInfo = file.split("/");
		const year = parseInt(fileInfo[0]);
		const month = parseInt(fileInfo[1]);
		const nameOfTheFolder = fileInfo[2]; // unique
		if (year && month && nameOfTheFolder) {
		    const regex = new RegExp(".+_(.+_.+)$");
		    const dateAndTimeStr = regex.exec(nameOfTheFolder)[1];
		    const timestamp = new Date(
			dateAndTimeStr.replace('_', ' ')
			    .insert(4,"/")
			    .insert(7,"/")
			    .insert(13,":")
			    .insert(16,":"));
		    if (!(nameOfTheFolder in reports)) {
			// eliminate duplicate entries and map reports
			reports[nameOfTheFolder] = {
			    "nameOfTheFolder": nameOfTheFolder,
		            "year": year,
		            "month": month,
			    "timestamp": timestamp,
		            "url": `/dashboard/Secure/QA/${year}/${month}/${nameOfTheFolder}/index.html`
			};
		    }
		    console.log(`folder: ${nameOfTheFolder}`);
		}
	    });
	    console.log('all reports: ');
	    console.log(reports);

	    let currMonth = 0;
	    var result = Object.keys(reports)
                .sort((a, b) => reports[a].timestamp - reports[b].timestamp)
                .map((reportKey) => {
                    const report = reports[reportKey];
		    report_html_block = `
                      <h3><span>${report.nameOfTheFolder.split('_').slice(0,-2).join(' ')}</span></h3>
                      <div id="${report.nameOfTheFolder}" class="clr"></div>
                      <a href="${report.url}">${report.nameOfTheFolder}</a></div>
                    `;
		    if (!(report.month === currMonth)) {
			$('.mainbar').append(`
                          <div id="month_${report.month}" class="report">
                           <h2><span>${monthsDigitToString[report.month-1]} ${report.year}</span></h2>
                          </div>`);
			currMonth = report.month;
		    }
		    $(`#month_${report.month}`).append(report_html_block);
                });
	}
    );
 });
