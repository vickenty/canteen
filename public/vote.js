$(function() {
    $('form').submit(function(ev) {
        ev.preventDefault();

        var $this = $(this);

        var url = $this.attr('action') || window.location.href;
        var data = $this.serialize();

        var $debug = $this.find('.debug_note');

        $.ajax({
            type: 'post',
            url: url,
            data: data,
            dataType: 'json',
            success: function() {
                $debug.text('Saved');
            },
            error: function() {
                $debug.text('Save failed');
            },
            complete: function() {
                $debug.addClass('debug_note_visible');
                setTimeout(function() {
                    $debug.removeClass('debug_note_visible');
                }, 1000);
            },
        });

        $this.trigger('vote:sent');
    });
});
