$(function() {
    $('*[data-clone]').each(function() {
        var $wrap = $(this);
        var seq = 0;
        $wrap.find('input').focus(function() {
            this.blur();
            var $block = $wrap.clone();
            $block.find('input').each(function() {
                var $input = $(this);
                $input.attr('name', $input.attr('name') + seq++);
            });
            $block.hide();
            $wrap.before($block);
            $block.slideDown();
            $block.find('input').focus();
        });
    });
});
