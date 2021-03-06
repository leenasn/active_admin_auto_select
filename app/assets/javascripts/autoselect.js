var AutoSelect;

AutoSelect = (function() {
  function AutoSelect(options) {
    this.options = options != null ? options : {};
    this.$input = $(this.options['input']);
    this.width = this.options['width'] || 240;
    this.placeholder = this.options['placeholder'];
    this.multiple = this.options['multiple'];
  }

  AutoSelect.prototype.init = function() {
    var scope, url;
    scope = this.$input.attr('data-scope');
    url = this.$input.attr('data-url');
    this.$input.select2({
      placeholder: this.placeholder,
      allowClear: true,
      minimumInputLength: 1,
      width: this.width,
      multiple: this.multiple,
      ajax: {
        url: url,
        quietMillis: 300,
        data: function(term, page) {
          return {
            q: term,
            page_limit: 10,
            page: page,
            scope: scope
          };
        },
        results: function(data, page) {
          var more;
          more = data.length >= 10;
          return {
            results: data,
            more: more
          };
        }
      },
      formatResult: (function(_this) {
        return function(item, container, query, escapeFn) {
          var markup, text;
          markup = [];
          window.Select2.util.markMatch(_this.detailText(item), query.term, markup, escapeFn);
          return text = markup.join('');
        };
      })(this),
      formatSelection: (function(_this) {
        return function(item, container, escapeFn) {
          return _this.detailText(item);
        };
      })(this),
      initSelection: (function(_this) {
        return function(e, callback) {
          var value, ids;
          value = $(e).val();
          ids = value.split(' ');
          if (value !== "") {
            return $.getJSON(url, {
              ids: ids
            }).done(function(data) {
              callback(data);
              return _this.$input.trigger("autocomplete:ajax:success", data);
            });
          }
        };
      })(this)
    });
    return this.$input.change('select2-selecting', function() {
      return $(this).closest('.filter_form').submit();
    });
  };

  AutoSelect.prototype.detailText = function(item) {
    return _.reject(_.uniq(_.toArray(item)), function(el) {
      return el === '';
    }).join(' - ');
  };

  return AutoSelect;

})();

// ---
// generated by coffee-script 1.9.2
