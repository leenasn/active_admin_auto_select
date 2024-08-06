require "active_admin_auto_select/version"
require "active_admin_auto_select/rails"

module AutoSelectable
  def auto_select(*fields)
    options = fields.extract_options!

    # The @resource instance variable seems unavailable in versions
    # later than 1.0.0.pre1 of the ActiveAdmin.
    resource = @resource || self.config.resource_class_name.constantize
    create_collection_action(fields, options, resource)
  end

  def create_collection_action(fields, options, resource)
    collection_action :autoselect, method: :get do
      # Rails.logger.debug "options #{options}"
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
          if params[:tags].present?
            tags = ActsAsTaggableOn::Tag.where("name IN (?)",
              params[:ids].collect do | id |
                id.gsub("[", "").gsub("]", "").gsub("\"", "").gsub(",", "")
              end
            )
            resources = tags.collect.each do | tag |
              { id: tag.id, name: tag.name.humanize }
            end
          else
            ids = params[:ids]
            if ids.is_a?(String)
              ids = params[:ids].gsub(/[^0-9,]/i, "0")
            elsif ids.is_a?(Array)
              ids = params[:ids].collect(&:to_i)
            end
            resources = effective_scope.call.
              where("#{resource.table_name}.id IN (?)", ids).
              select(select_fields)
            if resources.size == 1
              resources = resources.first
            else
              resources = resources.sort_by { |r| params[:ids].index(r.id.to_s) }
            end
          end
          render json: resources
          return
        else
          concat_fields = fields.join(" || ' '::text || ")
          studio = current_admin_user.super_admin? ? Studio.all : current_admin_user.studio
          if params[:scope] == "tags"
            tags = Customer.where(studio: studio).all_tags.
              where("lower(name) ILIKE '%#{term}%' AND name != 'imported'").
              select(:id, :name)
              .order("name")
            resource_records = tags.collect.each do | tag |
              { id: tag.id, name: tag.name.humanize }
            end
          else
            resource_records = effective_scope.call
                           .select(select_fields)
                           .where("#{concat_fields} ILIKE :term", term: "%#{term}%")
                           .where(studio: studio)
                           .order("name")
                           .limit(15).offset(offset)
          end
          render json: resource_records
        end
      end
    end
  end
end

ActiveAdmin::ResourceDSL.send :include, AutoSelectable
