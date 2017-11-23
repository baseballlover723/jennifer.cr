struct JohnyQuery < Jennifer::QueryBuilder::QueryObject
  def call
    relation.where { _name == "Johny" }
  end
end

struct WithArgumentQuery < Jennifer::QueryBuilder::QueryObject
  def call
    this = self
    relation.where { _age == this.params[0] }
  end
end

abstract class ApplicationRecord < Jennifer::Model::Base
  getter super_class_callback_called = false

  before_create :before_abstract_create

  def before_abstract_create
    @super_class_callback_called = true
  end
end

class Contact < ApplicationRecord
  with_timestamps
  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping(
      id:          Primary32,
      name:        String,
      ballance:    PG::Numeric?,
      age:         {type: Int32, default: 10},
      gender:      {type: String?, default: "male"},
      description: String?,
      created_at:  Time | Nil,
      updated_at:  Time?,
      tags: Array(Int32)?,
    )
  {% else %}
    mapping(
      id:          Primary32,
      name:        String,
      ballance:    Float64?,
      age:         {type: Int32, default: 10},
      gender:      {type: String?, default: "male"},
      description: String?,
      created_at:  Time | Nil,
      updated_at:  Time?,
    )
  {% end %}

  has_many :addresses, Address, inverse_of: :contact
  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, association_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}, inverse_of: :contact
  has_one :passport, Passport

  validates_inclucion :age, 13..75
  validates_length :name, minimum: 1, maximum: 15
  validates_with_method :name_check

  scope :main { where { _age > 18 } }
  scope :older { |age| where { _age >= age } }
  scope :ordered { order(name: :asc) }
  scope :with_main_address { relation(:addresses).where { _addresses__main } }
  scope :johny, JohnyQuery
  scope :by_age, WithArgumentQuery

  def name_check
    if @description && @description.not_nil!.size > 10
      errors.add(:description, "Too large description")
    end
  end
end

class Address < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: Int32?,
    details: JSON::Any?
  )
  validates_format :street, /st\.|street/

  belongs_to :contact, Contact

  scope :main { where { _main } }

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: Int32?
  )

  validates_with [EnnValidator]
  belongs_to :contact, Contact

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class Profile < ApplicationRecord
  mapping(
    id: Primary32,
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  sti_mapping(
    uid: String? # for testing purposes
  )

  validates_length :uid, is: 4

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  sti_mapping(
    email: {type: String, null: true} # for testing purposes
  )
end

class Country < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String?
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name
  validates_presence_of :name

  has_and_belongs_to_many :contacts, Contact

  {% for callback in %i(before_save after_save after_create before_create after_initialize before_destroy after_destroy) %}
    getter {{callback.id}}_attr = false

    {{callback.id}} {{callback}}_check

    def {{callback.id}}_check
      @{{callback.id}}_attr = true
    end
  {% end %}

  before_create :test_skip

  def test_skip
    if name == "not create"
      raise ::Jennifer::Skip.new
    end
  end

  def before_destroy_check
    if name == "not kill"
      errors.add(:name, "Cant destroy")
    end
    @before_destroy_attr = true
  end
end

class EnnValidator < Accord::Validator
  def initialize(context : Passport)
    @context = context
  end

  def call(errors : Accord::ErrorList)
    if @context.enn!.size < 4 && @context.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end

class OneFieldModel < Jennifer::Model::Base
  mapping(
    id: Primary32
  )
end

class OneFieldModelWithExtraArgument < Jennifer::Model::Base
  table_name "one_field_models"

  mapping(
    id: Primary32,
    missing_field: String
  )
end

class ContactWithNotAllFields < Jennifer::Model::Base
  table_name "contacts"

  mapping(
    id: Primary32,
    name: String?,
  )
end

class ContactWithNotStrictMapping < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end

class ContactWithDependencies < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:          Primary32,
    name:        String?,
    description: String?,
    age:         {type: Int32, default: 10},
    gender:      {type: String?, default: "male"},
  }, false)

  has_many :addresses, Address, dependent: :delete, foreign: :contact_id
  has_many :facebook_profiles, FacebookProfile, dependent: :nullify, foreign: :contact_id
  has_many :passports, Passport, dependent: :destroy, foreign: :contact_id
  has_many :twitter_profiles, TwitterProfile, dependent: :restrict_with_exception, foreign: :contact_id

  validates_length :name, minimum: 2
  validates_length :description, minimum: 2, allow_blank: true
end

class ContactWithCustomField < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String,
  }, false)
end

class ContactWithInValidation < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String?,
  }, false)

  validates_length :name, in: 2..10
end

class ContactWithNillableName < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end

class FemaleContact < Jennifer::Model::Base
  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end

# ===========
# views
# ===========

class MaleContact < Jennifer::View::Base
  mapping({
    id:     Primary32,
    name:   String,
    gender: String,
    age:    Int32,
  }, false)

  scope :main { where { _age < 50 } }
  scope :older { |age| where { _age >= age } }
  scope :johny, JohnyQuery
end

class FakeContactView < Jennifer::View::Base
  view_name "male_contacs"

  mapping({
    id: Primary32,
  }, false)
end

class StrinctBrokenMaleContact < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:   Primary32,
    name: String,
  })
end

class StrictMaleContactWithExtraField < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:            Primary32,
    missing_field: String,
  })
end

class MaleContactWithDescription < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:          Primary32,
    description: String,
  }, false)
end
