json.extract! notification, :id, :title, :description, :notification_type, :status, :start_date, :end_date, :created_at, :updated_at
json.url notification_url(notification, format: :json)
