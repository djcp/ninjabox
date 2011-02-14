$.noConflict();

jQuery(function(){
    jQuery('.download-link').click(function(e){
        var file_id = jQuery(this).attr('id').split('-')[1];
        jQuery.ajax({
            type: 'POST',
            cache: false,
            data: {rm: 'click', id: file_id}
        });
    });
    jQuery('.dmca-details-toggle').click(function(e){
        e.preventDefault();
        var id = jQuery(this).attr('id').split('-')[3];
        jQuery('#dmca-details-' + id).toggle('normal');
    });
});
