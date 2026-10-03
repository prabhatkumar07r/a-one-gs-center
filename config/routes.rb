Rails.application.routes.draw do

  root "sample#homepage"

  get "/homepage",
      to: "sample#homepage",
      as: :homepage

  get "/sample/homepage",
      to: "sample#homepage"


  resources :test_series,
            only: [:index, :show] do

    member do
      get :instructions
    end

    resources :test_series_tests,
              only: [:show],
              controller: "test_series_tests" do

      member do
        post :answer
        post :finish
        post :bookmark
      end

      resources :results,
                controller: "test_series_results",
                only: [:show]
    end
  end


  post "/test_series/:test_series_id/purchase",
       to: "test_series_purchases#create",
       as: :purchase_test_series


  get "/test_series_purchases/:id/payment",
      to: "test_series_purchases#payment",
      as: :test_series_payment

  post "/test_series_purchases/:id/verify",
       to: "test_series_purchases#verify",
       as: :verify_test_series_payment

post "/test_series_purchases/:id/apply_coupon",
     to: "test_series_purchases#apply_coupon",
     as: :apply_test_series_coupon

delete "/test_series_purchases/:id/remove_coupon",
       to: "test_series_purchases#remove_coupon",
       as: :remove_test_series_coupon
    

  get "/test_series_purchases/:id/payment/success",
      to: "test_series_purchases#success",
      as: :test_series_payment_success

  get "/test_series_purchases/:id/payment/failed",
      to: "test_series_purchases#failed",
      as: :test_series_payment_failed


  resources :events


  devise_for :users,
             controllers: {
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


  namespace :ai do

    resources :conversations,
              only: [:index, :show, :create, :destroy] do

      resources :messages,
                only: [:create]
    end

    resources :support_requests,
              only: [:index, :show, :create] do

      resources :messages,
                controller: "support_messages",
                only: [:index, :create]
    end

  end


  namespace :admin do

    resources :support_requests,
              only: [:index, :show, :update] do

      resources :messages,
                controller: "support_messages",
                only: [:index, :create]
    end


    resources :coupons


    resources :payments,
              only: [:index, :show] do

      member do
        post :send_email
        post :send_reminder
        post :sync
      end

      collection do
        post :bulk_send_reminders
      end

    end


    resources :testimonials do

      member do
        patch :toggle_status
      end

    end


    resources :ebook_purchases,
              only: [:index, :show] do

      member do
        post :verify_payment
      end

    end


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


    resource :profile,
             only: [:show, :edit, :update]


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


    resources :enrollments

  end


  get "/courses/:id/details",
      to: "courses#details",
      as: :course_details

  post "/courses/:id/enroll_free",
       to: "courses#enroll_free",
       as: :enroll_free_course


  post "/enrollments",
       to: "enrollments#create",
       as: :enrollments


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


  namespace :student do

    resources :enrollments

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


  get "/ebooks/my",
      to: "ebooks#my",
      as: :my_ebooks

  resources :ebooks,
            only: [:index, :show] do

    member do
      get :access
    end

  end


  post "/ebooks/:ebook_id/buy",
       to: "ebook_payments#create",
       as: :buy_ebook

  get "/ebook-payments/:id",
      to: "ebook_payments#show",
      as: :ebook_payment
  post "/ebook-payments/:id/apply_coupon",
     to: "ebook_payments#apply_coupon",
     as: :apply_ebook_coupon

delete "/ebook-payments/:id/remove_coupon",
       to: "ebook_payments#remove_coupon",
       as: :remove_ebook_coupon   

  post "/ebook-payments/:id/verify",
       to: "ebook_payments#verify",
       as: :verify_ebook_payment

  get "/ebook-payments/:id/success",
      to: "ebook_payments#success",
      as: :ebook_payment_success

  get "/ebook-payments/:id/failed",
      to: "ebook_payments#failed",
      as: :ebook_payment_failed


  resources :ebook_files,
            only: [:show] do

    member do
      get :download
    end

  end


  resources :notes,
            only: [:index, :show] do

    member do
      get :preview
      get :download
    end

  end


  resources :resources,
            only: [:index, :show]


  resources :courses,
            only: [] do

    resources :playlists,
              only: [] do

      resources :resources

    end

  end


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


  namespace :teacher_panel do

    resource :profile,
             only: [:show, :edit, :update],
             controller: "profile"


    resources :courses,
              only: [:index, :show] do

      resources :quizzes do
        resources :questions
      end

      resources :students,
                only: [:index]

      resources :videos

      resources :playlists

      resources :resources

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


  get "/courses/:course_id/attendances",
      to: "attendances#index",
      as: :course_attendances

  get "/courses/:course_id/attendances/new",
      to: "attendances#new",
      as: :new_course_attendance

  post "/courses/:course_id/attendances",
       to: "attendances#create",
       as: :create_course_attendance


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
  post "/razorpay/webhook",
     to: "razorpay_webhooks#payment",
     as: :razorpay_webhook     


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
            only: [
              :new,
              :create,
              :edit,
              :update
            ]


  get "/forgot_password",
      to: "password_resets#new",
      as: :forgot_password

  post "/forgot_password",
       to: "password_resets#create"


  post "/contacts",
       to: "contacts#create"


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


  get "/privacy-policy",
      to: "legal_pages#privacy_policy"

  get "/terms",
      to: "legal_pages#terms"

  get "/data-deletion",
      to: "legal_pages#data_deletion"


  get "/webhooks/whatsapp",
      to: "whatsapp_webhooks#verify"

  post "/webhooks/whatsapp",
       to: "whatsapp_webhooks#receive"


  namespace :admin do

    get "/whatsapp",
        to: "whatsapp_messages#index",
        as: :whatsapp

    get "/whatsapp/conversation/:phone",
        to: "whatsapp_messages#conversation",
        as: :whatsapp_conversation

    get "/whatsapp/conversation/:phone/messages",
        to: "whatsapp_messages#messages",
        as: :whatsapp_conversation_messages

    post "/whatsapp/conversation/:phone/send",
         to: "whatsapp_messages#send_message",
         as: :send_whatsapp_message

  end


  mount ActiveStorage::Engine =>
        "/rails/active_storage"

end