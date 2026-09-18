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


  # ==================================================
  # TEST SERIES - STUDENT
  # ==================================================

  resources :test_series,
            only: [:index, :show] do

    # Instructions page
    member do
      get :instructions
    end

    # Individual test
    resources :test_series_tests,
              only: [:show],
              controller: "test_series_tests" do

      # Answer / Submit actions
      member do
        post :answer
        post :finish
        post :bookmark
      end

      # Result
      resources :results,
                controller: "test_series_results",
                only: [:show]

    end
  end


  # ==================================================
  # TEST SERIES PURCHASE
  # ==================================================

  post "/test_series/:test_series_id/purchase",
       to: "test_series_purchases#create",
       as: :purchase_test_series


  # ==================================================
  # TEST SERIES PAYMENT
  # ==================================================

  get "/test_series_purchases/:id/payment",
      to: "test_series_purchases#payment",
      as: :test_series_payment

  post "/test_series_purchases/:id/verify",
       to: "test_series_purchases#verify",
       as: :verify_test_series_payment

  get "/test_series_purchases/:id/payment/success",
      to: "test_series_purchases#success",
      as: :test_series_payment_success

  get "/test_series_purchases/:id/payment/failed",
      to: "test_series_purchases#failed",
      as: :test_series_payment_failed


  # ==================================================
  # EVENTS
  # ==================================================

  resources :events


  # ==================================================
  # AUTHENTICATION - DEVISE
  # ==================================================

  devise_for :users,
             controllers: {
               sessions: "users/sessions",
               registrations: "users/registrations",
               omniauth_callbacks: "users/omniauth_callbacks"
             }


  # ==================================================
  # DEBUG / STORAGE / CLOUDINARY
  # ==================================================

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
    resources :coupons
    resources :payments, only: [:index,:show]
    resources :testimonials do
  member do
    patch :toggle_status
  end
end

    # ==================================================
    # E-BOOK PAYMENTS
    # ==================================================

    resources :ebook_purchases,
              only: [:index, :show] do

      member do
        post :verify_payment
      end

    end


    # ==================================================
    # E-BOOKS
    # ==================================================

    resources :ebooks do

      resources :ebook_files,
                only: [
                  :index,
                  :new,
                  :create,
                  :edit,
                  :update,
                  :destroy
                ]

    end


    # ==================================================
    # ADMIN TEST SERIES
    # ==================================================

    resources :test_series do

      resources :test_series_tests,
                as: :tests do

        resources :test_series_questions,
                  as: :questions do

          resources :test_series_options,
                    as: :options

        end

      end

    end




    # ==================================================
    # ADMIN PROFILE
    # ==================================================

    resource :profile,
             only: [:show, :edit, :update]


    # ==================================================
    # ADMIN SETTINGS
    # ==================================================

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


    # ==================================================
    # ADMIN COURSES
    # ==================================================

    resources :courses do

      resources :quizzes do
        resources :questions
      end

      resources :playlists do
        resources :videos
        resources :course_resources
      end

      resources :students,
                only: [:index]

    end


    # ==================================================
    # ADMIN ENROLLMENTS
    # ==================================================

    resources :enrollments

  end


  # ==================================================
  # PUBLIC COURSE DETAILS
  # ==================================================

  get "/courses/:id/details",
      to: "courses#details",
      as: :course_details

  post "/courses/:id/enroll_free",
       to: "courses#enroll_free",
       as: :enroll_free_course


  # ==================================================
  # STUDENT COURSE ENROLLMENT
  # ==================================================

  post "/enrollments",
       to: "enrollments#create",
       as: :enrollments


  # ==================================================
  # STUDENT QUIZ
  # ==================================================

  resources :courses,
            only: [] do

    resources :quizzes,
              only: [:index, :show] do

      member do
        post :start
        post :submit
      end

      get "attempts/:attempt_id/result",
          to: "quizzes#result",
          as: :result

    end

  end


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

    # ==================================================
    # STUDENT ENROLLMENTS
    # ==================================================

    resources :enrollments


    # ==================================================
    # STUDENT PROFILE
    # ==================================================

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
  # E-BOOK MODULE
  # ==================================================

  # --------------------------------------------------
  # PUBLIC E-BOOKS
  # --------------------------------------------------

  # IMPORTANT:
  # Keep /ebooks/my before /ebooks/:id
  get "/ebooks/my",
      to: "ebooks#my",
      as: :my_ebooks

  resources :ebooks,
            only: [:index, :show] do

    member do
      get :access
    end

  end


  # --------------------------------------------------
  # E-BOOK PURCHASE / PAYMENT
  # --------------------------------------------------

  post "/ebooks/:ebook_id/buy",
       to: "ebook_payments#create",
       as: :buy_ebook

  get "/ebook-payments/:id",
      to: "ebook_payments#show",
      as: :ebook_payment

  post "/ebook-payments/:id/verify",
       to: "ebook_payments#verify",
       as: :verify_ebook_payment

  get "/ebook-payments/:id/success",
      to: "ebook_payments#success",
      as: :ebook_payment_success

  get "/ebook-payments/:id/failed",
      to: "ebook_payments#failed",
      as: :ebook_payment_failed


  # --------------------------------------------------
  # E-BOOK PDF FILE ACCESS
  # --------------------------------------------------

  resources :ebook_files,
            only: [:show] do

    member do
      get :download
    end

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
# COURSE → PLAYLIST → RESOURCES
# ==================================================

resources :courses, only: [] do
  resources :playlists, only: [] do
    resources :resources
  end
end         


  # ==================================================
  # STUDY NOTES
  # ==================================================

  resources :study_notes,
            only: [
              :index,
              :new,
              :create,
              :edit,
              :update,
              :destroy
            ] do

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

    # ==================================================
    # TEACHER PROFILE
    # ==================================================

    resource :profile,
             only: [:show, :edit, :update],
             controller: "profile"


    # ==================================================
    # TEACHER COURSES
    # ==================================================

    resources :courses,
              only: [:index, :show] do

      # ==================================================
      # QUIZZES
      # ==================================================

      resources :quizzes do
        resources :questions
      end


      # ==================================================
      # STUDENTS
      # ==================================================

      resources :students,
                only: [:index]


      # ==================================================
      # VIDEOS
      # ==================================================

      resources :videos


      # ==================================================
      # PLAYLISTS
      # ==================================================

      resources :playlists


      # ==================================================
      # RESOURCES
      # ==================================================

      resources :resources


      # ==================================================
      # ATTENDANCE
      # ==================================================

      resources :attendances,
                only: [
                  :index,
                  :new,
                  :create,
                  :show,
                  :edit,
                  :update,
                  :destroy
                ]

    end


    # ==================================================
    # TEACHER TEST SERIES
    # ==================================================

    resources :test_series do

      resources :test_series_tests,
                as: :tests do

        resources :test_series_questions,
                  as: :questions do

          resources :test_series_options,
                    as: :options

        end

      end

    end

  end


  # ==================================================
  # COURSE ATTENDANCE
  # ==================================================

  get "/courses/:course_id/attendances",
      to: "attendances#index",
      as: :course_attendances

  get "/courses/:course_id/attendances/new",
      to: "attendances#new",
      as: :new_course_attendance

  post "/courses/:course_id/attendances",
       to: "attendances#create",
       as: :create_course_attendance


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
  # COURSE PAYMENTS / RAZORPAY
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

  post "payments/:id/apply_coupon",
     to: "payments#apply_coupon",
     as: :apply_coupon    


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
            only: [
              :new,
              :create,
              :edit,
              :update
            ]


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