Rails.application.routes.draw do

  # ==================================================
  # HOME
  # ==================================================

  root "sample#homepage"

  get "/homepage",
      to: "sample#homepage",
      as: :homepage

  get "/sample/homepage",
      to: "sample#homepage"

  resources :events


  # ==================================================
  # AUTHENTICATION (DEVISE)
  # ==================================================

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  get "/debug_env",
      to: "sample#debug_env"

  get "/cloudinary_check",
      to: "sample#cloudinary_check"

  get "/blob_check",
      to: "sample#blob_check"


  # ==================================================
  # DASHBOARDS
  # ==================================================

  get "/admin",
      to: "dashboard#index",
      as: :dashboard

  get "/teacher",
      to: "teacher_panel/dashboard#index",
      as: :teacher_dashboard

  get "/student/dashboard",
      to: "student_dashboard#index",
      as: :student_dashboard

  get "/smtp_test",
      to: "smtp_test#index"


  # ==================================================
  # ADMIN
  # ==================================================

  namespace :admin do

    # ================= ADMIN PROFILE =================

    resource :profile,
             only: [:show, :edit, :update]


    # ================= ADMIN SETTINGS =================

    get "settings",
        to: "settings#index"

    get "settings/notifications",
        to: "settings#notifications",
        as: :settings_notifications

    patch "settings/notifications",
          to: "settings#update_notifications",
          as: :update_settings_notifications

    get "settings/website",
        to: "settings#website",
        as: :settings_website

    patch "settings/website",
          to: "settings#update_website",
          as: :update_settings_website

    get "settings/security",
        to: "settings#security",
        as: :settings_security

    get "settings/password",
        to: "settings#password",
        as: :settings_password

    patch "settings/password",
          to: "settings#update_password",
          as: :update_settings_password


    # ================= ADMIN COURSES =================

    resources :courses do

      resources :playlists do
        resources :videos
        resources :course_resources
      end

    end


    # ================= ADMIN ENROLLMENTS =================

    resources :enrollments

  end


  # ==================================================
  # PUBLIC COURSE DETAILS
  # ==================================================

  get "/courses/:id/details",
      to: "courses#details",
      as: :course_details


  # ==================================================
  # LEARNING
  # ==================================================

  get "/learn",
      to: "learning#index",
      as: :learning

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
  # STUDENT
  # ==================================================

  namespace :student do

    # ================= STUDENT ENROLLMENTS =================

    resources :enrollments


    # ================= STUDENT PROFILE =================

    get "profile",
        to: "profile#show",
        as: :profile

    get "profile/edit",
        to: "profile#edit",
        as: :edit_profile

    patch "profile",
          to: "profile#update"

    get "profile/password",
        to: "profile#password",
        as: :profile_password

    patch "profile/change_password",
          to: "profile#change_password",
          as: :change_password_profile

  end


  # ==================================================
  # STUDENT NOTES
  # ==================================================

  resources :notes,
            only: [:index, :show] do

    member do
      get :preview
      get :download
    end

  end


  # ==================================================
  # STUDENT RESOURCES
  # ==================================================

  resources :resources,
            only: [:index, :show]


  # ==================================================
  # STUDY NOTES
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
  # TEACHER PANEL
  # ==================================================

  namespace :teacher_panel do

    get "profile/show"

    resources :courses,
              only: [:index, :show] do

      resources :students,
                only: [:index]

      resources :videos

      resources :playlists

      resources :resources

      resource :profile,
               only: [:show, :edit, :update]

    end

  end


  get "teacher/profile",
      to: "teacher_panel/profile#show",
      as: :teacher_profile


  # ==================================================
  # MAIN RESOURCES
  # ==================================================

  resources :demo_requests,
            only: [:new, :create]

  resources :students

  resources :teachers

  resources :attendances

  resources :batches

  resources :notifications

  resources :galleries

  resources :achievements

  resources :certificates,
            only: [:index, :show]


  # ==================================================
  # PAYMENTS / RAZORPAY
  # ==================================================

  get "/payments/:id",
      to: "payments#show",
      as: :payment

  post "/payments/:id",
       to: "payments#create",
       as: :create_payment

  post "/payments/:id/verify",
       to: "payments#verify",
       as: :verify_payment

  get "/payments/:id/success",
      to: "payments#success",
      as: :payment_success

  get "/payments/:id/failed",
      to: "payments#failed",
      as: :payment_failed


  # ==================================================
  # FEES
  # ==================================================

  resources :fees do

    collection do
      get :enrollment_fee
      get :report
      get :export
    end

  end


  # ==================================================
  # DEMOS
  # ==================================================

  resources :demos do

    collection do
      get :export
    end

  end


  # ==================================================
  # REGISTRATIONS
  # ==================================================

  resources :registrations


  # ==================================================
  # PASSWORD RESETS
  # ==================================================

  resources :password_resets,
            only: [:new, :create, :edit, :update]


  # ==================================================
  # FORGOT PASSWORD
  # ==================================================

  get "/forgot_password",
      to: "password_resets#new",
      as: :forgot_password

  post "/forgot_password",
       to: "password_resets#create"


  # ==================================================
  # CONTACT
  # ==================================================

  post "/contacts",
       to: "contacts#create"


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

          get "categories/:category",
              to: "notes#by_category"
        end

      end

      get "health",
          to: "application#health_check"

    end

  end


  # ==================================================
  # ACTIVE STORAGE
  # ==================================================

  mount ActiveStorage::Engine =>
        "/rails/active_storage"

end