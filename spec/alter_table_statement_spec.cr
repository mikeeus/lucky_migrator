require "./spec_helper"

describe LuckyMigrator::AlterTableStatement do
  it "can alter tables with defaults, indices and options" do
    built = LuckyMigrator::AlterTableStatement.new(:users).build do
      add name : String?
      add email : String, fill_existing_with: "noreply@lucky.com"
      add nickname : String, fill_existing_with: :nothing
      add age : Int32, default: 1, unique: true
      add num : Int64, default: 1, index: true
      add amount_paid : Float, default: 1.0, precision: 10, scale: 5
      add completed : Bool, default: false
      add joined_at : Time, default: :now
      add updated_at : Time, fill_existing_with: :now
      add future_time : Time, default: Time.new
      remove :old_field
      remove_belongs_to :employee
    end

    built.statements.size.should eq 7
    built.statements.first.should eq <<-SQL
    ALTER TABLE users
      ADD name text,
      ADD email text,
      ADD nickname text NOT NULL,
      ADD age int NOT NULL DEFAULT 1,
      ADD num bigint NOT NULL DEFAULT 1,
      ADD amount_paid decimal(10,5) NOT NULL DEFAULT 1.0,
      ADD completed boolean NOT NULL DEFAULT false,
      ADD joined_at timestamptz NOT NULL DEFAULT NOW(),
      ADD updated_at timestamptz,
      ADD future_time timestamptz NOT NULL DEFAULT '#{Time.new.to_utc}',
      DROP old_field,
      DROP employee_id
    SQL

    built.statements[1].should eq "CREATE UNIQUE INDEX users_age_index ON users USING btree (age);"
    built.statements[2].should eq "CREATE INDEX users_num_index ON users USING btree (num);"
    built.statements[3].should eq "UPDATE users SET email = 'noreply@lucky.com';"
    built.statements[4].should eq "ALTER TABLE users ALTER COLUMN email SET NOT NULL;"
    built.statements[5].should eq "UPDATE users SET updated_at = NOW();"
    built.statements[6].should eq "ALTER TABLE users ALTER COLUMN updated_at SET NOT NULL;"
  end

  describe "associations" do
    it "can create associations" do
      built = LuckyMigrator::AlterTableStatement.new(:comments).build do
        add_belongs_to user : User, on_delete: :cascade
        add_belongs_to post : Post?, on_delete: :restrict
        add_belongs_to category_label : CategoryLabel, on_delete: :nullify, references: :custom_table
        add_belongs_to employee : User, on_delete: :cascade
      end

      built.statements.first.should eq <<-SQL
      ALTER TABLE comments
        ADD user_id int NOT NULL REFERENCES users ON DELETE CASCADE,
        ADD post_id int REFERENCES posts ON DELETE RESTRICT,
        ADD category_label_id int NOT NULL REFERENCES custom_table ON DELETE SET NULL,
        ADD employee_id int NOT NULL REFERENCES users ON DELETE CASCADE
      SQL

      built.statements[1].should eq "CREATE INDEX comments_user_id_index ON comments USING btree (user_id);"
      built.statements[2].should eq "CREATE INDEX comments_post_id_index ON comments USING btree (post_id);"
      built.statements[3].should eq "CREATE INDEX comments_category_label_id_index ON comments USING btree (category_label_id);"
      built.statements[4].should eq "CREATE INDEX comments_employee_id_index ON comments USING btree (employee_id);"
    end

    it "raises error when on_delete strategy is invalid or nil" do
      expect_raises Exception, "on_delete: :cascad is not supported. Please use :do_nothing, :cascade, :restrict, or :nullify" do
        LuckyMigrator::AlterTableStatement.new(:users).build do
          add_belongs_to user : User, on_delete: :cascad
        end
      end
    end
  end
end
