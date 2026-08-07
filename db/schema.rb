# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_05_115149) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "rank"
    t.boolean "status"
    t.string "student_name"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "year"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.date "date"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["course_id"], name: "index_attendances_on_course_id"
    t.index ["user_id"], name: "index_attendances_on_user_id"
  end

  create_table "batch_students", force: :cascade do |t|
    t.integer "batch_id", null: false
    t.datetime "created_at", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_batch_students_on_batch_id"
    t.index ["student_id"], name: "index_batch_students_on_student_id"
  end

  create_table "batches", force: :cascade do |t|
    t.string "batch_name"
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "room_no"
    t.date "start_date"
    t.string "status"
    t.integer "teacher_id", null: false
    t.string "timing"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_batches_on_course_id"
    t.index ["teacher_id"], name: "index_batches_on_teacher_id"
  end

  create_table "certificates", force: :cascade do |t|
    t.string "certificate_no"
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.date "issued_on"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["course_id"], name: "index_certificates_on_course_id"
    t.index ["user_id"], name: "index_certificates_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "message"
    t.string "name"
    t.string "subject"
    t.datetime "updated_at", null: false
  end

  create_table "courses", force: :cascade do |t|
    t.string "Course_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "discount_percentage"
    t.string "duration"
    t.integer "fee"
    t.text "learning_outcomes"
    t.decimal "original_fee"
    t.text "requirements"
    t.string "status"
    t.integer "teacher_id", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_courses_on_teacher_id"
  end

  create_table "demos", force: :cascade do |t|
    t.string "batch"
    t.string "city"
    t.string "course"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.string "preferred_time"
    t.string "status", default: "Pending"
    t.datetime "updated_at", null: false
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "status"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "fees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "due_amount"
    t.integer "enrollment_id", null: false
    t.decimal "paid_amount"
    t.date "payment_date"
    t.string "payment_mode"
    t.string "receipt_no"
    t.string "status"
    t.decimal "total_fee"
    t.datetime "updated_at", null: false
    t.index ["enrollment_id"], name: "index_fees_on_enrollment_id"
  end

  create_table "galleries", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "notes", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "download_count"
    t.string "file_size"
    t.string "file_url"
    t.integer "playlist_id"
    t.string "subject"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "video_id"
    t.index ["playlist_id"], name: "index_notes_on_playlist_id"
    t.index ["video_id"], name: "index_notes_on_video_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.string "notification_type"
    t.date "start_date"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.integer "enrollment_id", null: false
    t.string "razorpay_order_id"
    t.string "razorpay_payment_id"
    t.string "razorpay_signature"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["enrollment_id"], name: "index_payments_on_enrollment_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_playlists_on_course_id"
  end

  create_table "rename_to_column_courses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "resources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "playlist_id", null: false
    t.integer "resource_type"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["playlist_id"], name: "index_resources_on_playlist_id"
  end

  create_table "students", force: :cascade do |t|
    t.integer "age"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "mobile"
    t.string "name"
    t.string "password"
    t.datetime "resets_password_sent_at"
    t.string "resets_password_token"
    t.string "role"
    t.datetime "updated_at", null: false
  end

  create_table "teachers", force: :cascade do |t|
    t.integer "Contact_number"
    t.integer "age"
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "designation"
    t.string "email"
    t.integer "experience"
    t.string "facebook"
    t.string "gmail"
    t.string "instagram"
    t.date "joining_date"
    t.string "linkedin"
    t.string "mobile"
    t.string "name"
    t.string "qualification"
    t.decimal "salary"
    t.string "status"
    t.string "subject"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_teachers_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "age"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "image"
    t.string "mobile"
    t.string "name"
    t.string "password"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "video_progresses", force: :cascade do |t|
    t.boolean "completed"
    t.datetime "created_at", null: false
    t.datetime "last_watched_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "video_id", null: false
    t.index ["user_id"], name: "index_video_progresses_on_user_id"
    t.index ["video_id"], name: "index_video_progresses_on_video_id"
  end

  create_table "videos", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "duration"
    t.integer "playlist_id"
    t.integer "position", default: 1, null: false
    t.integer "status", default: 1
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["course_id"], name: "index_videos_on_course_id"
    t.index ["playlist_id"], name: "index_videos_on_playlist_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "courses"
  add_foreign_key "attendances", "users"
  add_foreign_key "batch_students", "batches"
  add_foreign_key "batch_students", "students"
  add_foreign_key "batches", "courses"
  add_foreign_key "batches", "teachers"
  add_foreign_key "certificates", "courses"
  add_foreign_key "certificates", "users"
  add_foreign_key "courses", "teachers"
  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "users"
  add_foreign_key "fees", "enrollments"
  add_foreign_key "notes", "playlists"
  add_foreign_key "notes", "videos"
  add_foreign_key "payments", "enrollments"
  add_foreign_key "playlists", "courses"
  add_foreign_key "resources", "playlists"
  add_foreign_key "teachers", "users"
  add_foreign_key "video_progresses", "users"
  add_foreign_key "video_progresses", "videos"
  add_foreign_key "videos", "courses"
  add_foreign_key "videos", "playlists"
end
