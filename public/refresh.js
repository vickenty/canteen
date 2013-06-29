$(function() {
    var date = document.getElementById('date');
    date = date && date.value;

    function try_refresh() {
        $.ajax({
            type: 'post',
            url: '/refresh',
            data: {
                date: date
            },
            success: function(data) {
                console.log(data);
                if (data && data.refresh)
                    location.reload();
                else
                    schedule();
            },
            error: function() {
                window.console && console.log(["err", arguments]);
            }
        });
    }

    function schedule() {
        setTimeout(try_refresh, 60000);
    }

    schedule();
});
