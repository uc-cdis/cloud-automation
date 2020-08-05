// fetch the indexd data in the background
let dataPromise = fetch("data/icgc.json").then(
  res => res.json()
).then(
  recList => recList.reduce((acc, it) => { acc[it.url] = it.did; return acc; }, {})
);

export function main() {
  const inputTextArea = document.body.querySelector('textarea.p2m-input__data');
  const button = document.querySelector('button.p2m-input__button');
  const results = document.querySelector('pre.p2m-results');

  button.addEventListener('click', async (el, ev) => {
    const data = await dataPromise;
    const textArea = document.body.querySelector('textarea.p2m-input__data');
    const resultsArea = document.body.querySelector('pre.p2m-input__results');
    const pathList = textArea.value.split(/[\r\n]+/
      ).filter(s => s.startsWith("s3://")
      ).map((url) => { return {url, did:data[url]}; }
      );
    const resultStr = pathList.map(
        info => `# ${info.url}\n${info.did || "# no did found"}`
      ).join("\n");
    resultsArea.innerText = resultStr;
  });
}


main();