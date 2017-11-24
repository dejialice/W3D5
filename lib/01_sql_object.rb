require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    cols = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    @columns = cols.map { |col| col.to_sym }
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do
        attributes[column]
      end
      define_method("#{column}=") do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.downcase + 's'
  end

  def self.all
    var = self.name.downcase + 's'
    results = DBConnection.execute2(<<-SQL)
    SELECT
      #{var}.*
    FROM
      #{var}
    SQL
    parse_all(results[1..-1])
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    self.all.find { |obj| obj.id == id }
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      if self.class.columns.include?(attr_name.to_sym)
        self.send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end

    # ...
  end

  def attributes
    @attributes ||= {}

  end

  def attribute_values
    values = []
    self.attributes.map do |key, value|
      values << value
    end
    values
  end

  def insert
    columns = self.class.columns.reject { |el| el == :id }
    question_marks = (["?"] * (columns.length)).join(', ')
    columns = columns.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{self.class.table_name} (#{columns})
    VALUES
      (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |attr| "#{attr} = ?" }.join(', ')
    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        #{self.class.table_name}.id = ?
      SQL
  end

  def save
    if id.nil?
      insert
    else
      update
    end 

  end
end
