
(function() {
    function handleClick(ev) {
        const did = ev.target.dataset.gen3Did;
        if (did) {
            fetch(`/user/data/download/${did}`).then(
                res => res.json()
            ).then(
                (data) => {
                    window.open(data.url, '_blank');
                }
            );
        }
    }

    document.querySelectorAll('[data-gen3-did]').forEach(
        (el) => {
            el.addEventListener('click', handleClick);
        }
    );
})();
