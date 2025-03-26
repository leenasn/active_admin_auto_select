require "active_admin_auto_select/version"
require "active_admin_auto_select/rails"

module AutoSelectable
  def auto_select(*fields)
    create_collection_action(fields, fields.extract_options!)
  end

  def create_collection_action(fields, options)
    collection_action :autoselect, method: :get do
      resource = self.resource_class
      select_fields = "id, " << fields.join(", ")
      if (Module.const_get(:CanCanCan) rescue false) ? authorized?(:read, resource) : true
        term = params[:q].to_s.dup
        term.gsub!("%", "\\\%")
        term.gsub!("_", "\\\_")
        page = params[:page].try(:to_i)
        offset = page ? (page - 1) * 10 + (5 * (page - 1)) : 0
        effective_scope = options[params[:scope]] ||
          options["default_scope"] || -> { resource }

        # This param exists when we have a filtered result
        if params[:ids].present?
          ids = params[:ids]
          if ids.is_a?(String)
            ids = params[:ids].gsub(/[^0-9,]/i, "0")
          elsif ids.is_a?(Array)
            ids = params[:ids].collect(&:to_i)
          end
          resources = effective_scope.call.
            where("#{resource.quoted_table_name}.id IN (?)", ids).
            select(select_fields)
          if resources.size == 1
            resources = resources.first
          else
            resources = resources.sort_by { |r| params[:ids].index(r.id.to_s) }
          end
          render json: resources
          return
        else
          concat_fields = fields.join(" || ' '::text || ")
          studio = current_admin_user.super_admin? ? Studio.all : current_admin_user.studio
          resource_records = effective_scope.call
                          .select(select_fields)
                          .where("#{concat_fields} ILIKE :term", term: "%#{term}%")
                          .where(studio: studio)
                          .order("name")
                          .limit(15).offset(offset)
          render json: resource_records
        end
      end
    end
  end
end

ActiveAdmin::ResourceDSL.send :include, AutoSelectable
