# These aren't expected to be called by a developer. They are internal methods.
module EffectiveDatatablesPrivateHelper

  # https://datatables.net/reference/option/columns
  def datatable_columns(datatable)
    form = nil
    simple_form_for(:datatable_search, url: '#', html: {id: "#{datatable.to_param}-form"}) { |f| form = f }

    datatable.columns.map do |name, opts|
      {
        name: name,
        title: content_tag(:span, (opts[:label] == false ? '' : opts[:label]), class: 'search-label'),
        className: opts[:col_class],
        searchHtml: (datatable_search_tag(datatable, name, opts) unless datatable.simple?),
        responsivePriority: opts[:responsive],
        search: datatable.state[:search][name],
        sortable: (opts[:sort] && !datatable.simple?),
        visible: datatable.state[:visible][name],
      }
    end.to_json.html_safe
  end

  def datatable_bulk_actions(datatable)
    if datatable._bulk_actions.present?
      render(partial: '/effective/datatables/bulk_actions_dropdown', locals: { datatable: datatable }).gsub("'", '"').html_safe
    end
  end

  def datatable_reset(datatable)
    render(partial: '/effective/datatables/reset', locals: { datatable: datatable }).gsub("'", '"').html_safe
  end

  def datatable_new_resource_button(datatable, name, column)
    return unless column[:inline] && (column[:actions][:new] != false)

    action = { action: :new, class: ['btn', column[:btn_class].presence].compact.join(' '), 'data-remote': true }

    if column[:actions][:new].kind_of?(Hash) # This might be active_record_array_collection?
      actions = action.merge(column[:actions][:new])

      effective_resource = (datatable.effective_resource || datatable.fallback_effective_resource)
      klass = (column[:actions][:new][:klass] || effective_resource&.klass || datatable.collection_class)
    elsif Array(datatable.effective_resource&.actions).include?(:new)
      effective_resource = datatable.effective_resource
      klass = effective_resource.klass
    else
      return
    end

    # Will only work if permitted
    render_resource_actions(klass, actions: { t('effective_datatables.new') => action }, effective_resource: effective_resource)
  end

  def datatable_search_tag(name, value, opts)

    return datatable_new_resource_button(datatable, name, opts) if name == :_actions

    return if opts[:search] == false

    # Build the search
    @_effective_datatables_form_builder || effective_form_with(scope: 'datatable_search', url: '#') { |f| @_effective_datatables_form_builder = f }
    form = @_effective_datatables_form_builder

    collection = opts[:search].delete(:collection)
    value = datatable.state[:search][name]

    options = opts[:search].merge(
      name: nil,
      feedback: false,
      label: false,
      value: value,
      data: { 'column-name': name, 'column-index': opts[:index] }
    )

    options.delete(:fuzzy)

    case options.delete(:as)
    when :string, :text, :number
      form.text_field name, options
    when :date, :datetime
      form.date_field name, options.reverse_merge(
        date_linked: false, prepend: false, input_js: { useStrict: true, keepInvalid: true }
      )
    when :time
      form.time_field name, options.reverse_merge(
        date_linked: false, prepend: false, input_js: { useStrict: false, keepInvalid: true }
      )
    when :select, :boolean
      options[:input_js] = (options[:input_js] || {}).reverse_merge(placeholder: '')

      form.select name, collection, options
    when :bulk_actions
      options[:data]['role'] = 'bulk-actions'
      form.check_box name, options.merge(label: '&nbsp;')
    end
  end
end
