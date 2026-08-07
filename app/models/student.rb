class Student < ApplicationRecord
  has_many :enrollments,dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :attendances
  has_many :batch_students
has_many :batches, through: :batch_students
  
  # Validations
  validates :name, presence: true,
                   length: { minimum: 3, maximum: 50 }
  
  validates :email, presence: true,
                      uniqueness: true,
                      format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

    validates :mobile,
              presence: true,
              uniqueness: true,
              format: { with: /\A[6-9]\d{9}\z/ }
              
    validates :password,
              length: { minimum: 8 }
    
    # ========== ROLE METHODS ==========
    
    before_save :set_default_role
    
    def admin?
      role == 'admin'
    end
    
    def teacher?
      role == 'teacher'
    end
    
    def student?
      role == 'student'
    end
    
    def role_name
      case role
      when 'admin'
        'Administrator'
      when 'teacher'
        'Teacher'
      else
        'Student'
      end
    end
    
    private
    
    def set_default_role
      self.role = 'student' if role.blank?
    end
end