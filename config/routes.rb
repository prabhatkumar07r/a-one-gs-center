Rails.application.routes.draw do
  # ==================================================
  # Home
  # ==================================================

  root "sample#homepage"

  get "/homepage", to: "sample#homepage", as: :homepage
  get "/sample/homepage", to: "sample#homepage"
  resources :events

  # ==================================================
  # Authentication (Devise)
  # ==================================================

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  get "/debug_env", to: "sample#debug_env"
  get "/cloudinary_check", to: "sample#cloudinary_check"
  get "/blob_check", to: "sample#blob_check"

  # ==================================================
  # Dashboards
  # ==================================================

  get "/admin", to: "dashboard#index", as: :dashboard
  get "/teacher", to: "teacher_panel/dashboard#index", as: :teacher_dashboard
  get "/student/dashboard", to: "student_dashboard#index", as: :student_dashboard
  get "/smtp_test", to: "smtp_test#index"

  # ==================================================
  # Learning
  # ==================================================

  get "/learn", to: "learning#index", as: :learning

  get "/learn/:id",
      to: "learning#show",
      as: :learning_course

  get "/learn/:course_id/videos/:id",
      to: "learning#video",
      as: :learning_video

  post "/learn/:course_id/videos/:id/complete",
       to: "learning#complete_video",
       as: :complete_learning_video

  # ==================================================
  # Course Details
  # ==================================================

  get "/courses/:id/details",
      to: "courses#details",
      as: :course_details

  # ==================================================
  # Student Notes
  # ==================================================

  resources :notes, only: [:index, :show] do
    member do
      get :preview
      get :download
    end
  end

  # ==================================================
  # Student Resources
  # ==================================================

  resources :resources, only: [:index, :show]

  # ==================================================
  # Study Notes
  # ==================================================

  resources :study_notes,
            only: [:index, :new, :create, :edit, :update, :destroy] do
    collection do
      get :playlists
      get :videos
    end

    member do
      get :download
    end
  end

  # ==================================================
  # Teacher Panel
  # ==================================================

  namespace :teacher_panel do
    resources :courses, only: [:index, :show] do
      resources :students, only: [:index]
      resources :videos
      resources :playlists
      resources :resources
    end
  end

  # ==================================================
  # Admin Courses
  # ==================================================

  resources :courses do
    resources :playlists do
      resources :videos
      resources :course_resources
    end
  end

  # ==================================================
  # Main Resources
  # ==================================================

  resources :demo_requests, only: [:new, :create]

  resources :students
  resources :teachers
  resources :enrollments
  resources :attendances
  resources :batches
  resources :notifications
  resources :galleries
  resources :achievements

  resources :certificates, only: [:index, :show]

  resources :payments do
    member do
      get :success
      get :failed
    end

    collection do
      post :webhook
    end
  end

  resources :fees do
    collection do
      get :enrollment_fee
      get :report
      get :export
    end
  end

  resources :demos do
    collection do
      get :export
    end
  end

  resources :registrations

  resources :password_resets,
            only: [:new, :create, :edit, :update]

  # ==================================================
  # Forgot Password
  # ==================================================

  get "/forgot_password",
      to: "password_resets#new",
      as: :forgot_password

  post "/forgot_password",
       to: "password_resets#create"

  # ==================================================
  # Contact
  # ==================================================

  post "/contacts", to: "contacts#create"

  # ==================================================
  # API
  # ==================================================

  namespace :api do
    namespace :v1 do
      resources :notes do
        member do
          get :download
        end

        collection do
          get :search
          get "categories/:category", to: "notes#by_category"
        end
      end

      get "health", to: "application#health_check"
    end
  end

  # ==================================================
  # Active Storage
  # ==================================================

  mount ActiveStorage::Engine => "/rails/active_storage"
end