$(function() {
    var date = document.getElementById('date').value;

    function try_refresh() {
        $.ajax({
            type: 'post',
            url: '/refresh',
            data: {
                date: date
            },
            success: function(data) {
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
        setTimeout(try_refresh, 30000);
    }

    if (date)
        schedule();
    else
        setTimeout(function() { location.reload() }, 15000);
});
