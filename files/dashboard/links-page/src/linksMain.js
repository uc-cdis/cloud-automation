// fetch the indexd data in the background
let dataPromise = fetch("./").then(
  res => res.json()
).catch(
  (err) => {
    const errNode = document.body.querySelector(".links-linklist__error");
    errNode.innerText = "Failed to load directory data";
    return [];
  }
);

export async function main() {
  const title = document.body.querySelector('.links-linklist__title');
  title.innerText = document.location.pathname.replace(/[^\/]+$/, '');
  let   data = await dataPromise;
  const linkListNode = document.querySelector('.links-linklist__list');
  data.map(
    (it) => {
      const li = document.createElement("LI");
      const anchor = document.createElement("A");
      li.className = "links-linklist__link"
      li.appendChild(anchor);
      anchor.setAttribute('href', `./${it}`);
      anchor.innerText = it;
      return li;
    }
  ).forEach(
    (li) => {
      linkListNode.appendChild(li);
    }
  );
}


main();