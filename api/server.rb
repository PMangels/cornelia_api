require 'sinatra'
require 'mysql2'
require 'json'
require 'logger'

require 'sinatra/base'
require 'sinatra/browse'


class App < Sinatra::Base
    register Sinatra::Browse
    ::Logger.class_eval { alias :write :'<<' }
    access_log = ::File.join(::File.dirname(::File.expand_path(__FILE__)),'log','access.log')
    access_logger = ::Logger.new(access_log)
    configure do
        use ::Rack::CommonLogger, access_logger
    end

    $db_host  = "mysql-cornelia" #"localhost" #"icts-db-mysqldb2.icts.kuleuven.be"
    $db_user  = "cornelia_api" #"www_cornelia_ro2"
    $db_pass  = "zC4%08U%Lm7y&0TP" #"gi7aeW6s"
    $db_name  = "www_cornelia2"
    $db_port  = 3306

    before do
        response.headers['Access-Control-Allow-Origin'] = '*'
        puts "BEFORE"

    end

    # The docs hosted on the server.
    get '/documentation' do
        File.read(File.join('public', 'docs.html'))
    end


    # The docs hosted on the server, used for group 1 of the user study.
    get '/docs1' do
        File.read(File.join('public', 'docs.html'))
    end

    # The docs hosted on the server, used for group 2 of th user study.
    get '/docs2' do
        File.read(File.join('public', 'alt_docs.html'))
    end




    # TODO: datatypes?
    # -------------------------------------------------- ARCHIVES --------------------------------------------------
    #       General information on the archives stored in the database

    # /archives/year_limits
    #       Returns the first and the last year for which there are entries present in the database.
    #
    #       return
    #           first_year: The first year for which there is an entry
    #           last_year: The last year for which there is an entry
    get '/archives/year_limits' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT MIN(date_year) as first_year, MAX(date_year) as last_year from source_entry;")
        cdr_result.first.to_json
    end

    # /archives/count
    #       Returns the amount of entries present in the database.
    #
    #       return
    #           count: The count of entries
    get '/archives/count' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT COUNT(id) as count from source_entry;")
        cdr_result.first.to_json
    end

    # -------------------------------------------------- ACTOR --------------------------------------------------
    #       Information pertaining to the actors in the database.

    # /actor/id?first_name&surname
    #       Returns the ids of the people matching the first and surname provided exactly
    #
    #       params
    #           first_name: The first name of the actor
    #           surname: The surname of the actor
    #
    #       return
    #           List of:
    #               id: The id matching the given name
    param :first_name, :String, required: true
    param :surname, :String, required: true
    get '/actor/id' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id FROM actor WHERE first_name='#{params[:first_name]}' AND surname='#{params[:surname]}';")
        cdr_result.to_a.to_json
    end

    # /actor/search?name&variants
    #       Returns a list of actors matching the description given in name.
    #       This does not have to be the complete name and variants of this name that were recorded can be searched as well.
    #
    #       param
    #           name: The name of the person that is being searched for.
    #           variants (default=0): Whether or not to search the variants of names.
    #       return
    #           List of:
    #               id: The id of the actor matching the description
    #               first_name: The first name of the actor
    #               surname: The surname of the actor
    #               variant: The variant of the actor's name (if variants is 1)
    #               variant_source_entry_id: The id of the entry containing the reference to the variant (if variants is 1)
    #       error
    #           400: if variants is not in (0,1)
    param :name, :String, required: true
    param :variants, :Integer, default: 0
    get '/actor/search'do
        unless [0, 1].include? params[:variants]
            halt 400, "The provided parameter variants represents a boolean and should be either 0 or 1."
        end

        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        if params[:variants] == 0
            cdr_result = client.query("SELECT id, first_name, surname
                FROM actor
                WHERE CONCAT_WS(' ', first_name, surname) LIKE '%#{params[:name]}%' OR
                    CONCAT_WS(' ', surname, first_name) LIKE '%#{params[:name]}%';")
        else

            cdr_result = client.query("SELECT actor.id, actor.first_name, actor.surname, name_variant.name AS variant, name_variant.source_entry_id AS variant_source_entry_id
                FROM actor
                INNER JOIN name_variant ON actor.id=name_variant.actor_id
                WHERE CONCAT_WS(' ', first_name, surname) LIKE '%#{params[:name]}%' OR
                    CONCAT_WS(' ', surname, first_name) LIKE '%#{params[:name]}%' OR
                    name_variant.name LIKE '%#{params[:name]}%';")
        end

        cdr_result.to_a.to_json
    end

    # /actor/info?id
    #       Returns the information of the actor identified by the id.
    #
    #       params
    #           id: The id of the actor
    #
    #       return
    #           first_name: The first name of the actor
    #           surname: The surname of the actor
    #           gender: The gender of the actor (male or female)
    #           incomplete: Indicates whether the record of the actor is incomplete (1=incomplete, 0=complete)
    param :id, :Integer, required: true
    get '/actor/info' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT first_name, surname, gender, incomplete FROM actor WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end

    $actor_info_list  = ["first_name", "surname", "gender", "incomplete"]

    # /actor/:actor_info?id
    #       Returns the :actor_info of the actor identified by the id.
    #
    #       params
    #           id: The id of the actor
    #
    #       return
    #           :actor_info: The :actor_info of the actor
    param :id, :Integer, required: true
    get '/actor/:actor_info' do
        pass unless $actor_info_list.include? params[:actor_info]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT #{params[:actor_info]} FROM actor WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end

    # /actor/lifespan?id
    #       Returns the lifespan of the person identified by the id, based on their baptism and their burial date.
    #
    #       params
    #           id: The id of the actor
    #
    #       return
    #           year_of_birth: The year in which the person was born, can be null
    #           month_of_birth: The month in which the person was born, can be null
    #           day_of_birth: The day in which the person was born, can be null
    #           source_entry_birth_id: The id of the source entry which recorded this birth
    #           year_of_death: The year in which the person died, can be null
    #           month_of_death: The month in which the person died, can be null
    #           day_of_death: The day in which the person died, can be null
    #           source_entry_death_id: The id of the source entry which recorded this death
    param :id, :Integer, required: true
    get '/actor/lifespan' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)

        #Check if a baptised result and a buried result is available
        baptised_result = client.query("SELECT count(*) AS count
            FROM actor_actor
            INNER JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
            WHERE actor_actor.actor_id=#{params[:id]} AND role_personal.name='baptised';")
        buried_result = client.query("SELECT count(*) AS count
            FROM actor_actor
            INNER JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
            WHERE actor_actor.actor_id=#{params[:id]} AND role_personal.name='buried';")
        baptised_available = baptised_result.first["count"] > 0
        buried_available = buried_result.first["count"] > 0


        if baptised_available && buried_available
            cdr_result = client.query("SELECT bse.date_day AS day_of_birth, bse.date_month AS month_of_birth, bse.date_year AS year_of_birth, bse.id AS source_entry_birth_id,
                dse.date_day AS day_of_death, dse.date_month AS month_of_death, dse.date_year AS year_of_death, dse.id AS source_entry_death_id

                FROM actor_actor AS baa
                INNER JOIN actor_actor AS daa ON baa.actor_id=daa.actor_id

                INNER JOIN role_personal AS brp ON baa.role_personal_id=brp.id
                INNER JOIN source_entry AS bse ON baa.source_entry_id=bse.id

                INNER JOIN role_personal AS drp ON daa.role_personal_id=drp.id
                INNER JOIN source_entry AS dse ON daa.source_entry_id=dse.id

                WHERE brp.name='baptised' AND drp.name='buried' AND baa.actor_id = #{params[:id]};")
        elsif !baptised_available && buried_available
            cdr_result = client.query("SELECT NULL AS day_of_birth, NULL AS month_of_birth, NULL AS year_of_birth, NULL AS source_entry_birth_id,
                date_day AS day_of_death, date_month AS month_of_death, date_year AS year_of_death, source_entry.id AS source_entry_death_id
                FROM actor_actor

                INNER JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
                INNER JOIN source_entry ON actor_actor.source_entry_id=source_entry.id

                WHERE role_personal.name='buried' AND actor_id = #{params[:id]};")
        elsif baptised_available && !buried_available
            cdr_result = client.query("SELECT date_day AS day_of_birth, date_month AS month_of_birth, date_year AS year_of_birth, source_entry.id AS source_entry_birth_id,
                NULL AS day_of_death, NULL AS month_of_death, NULL AS year_of_death, NULL AS source_entry_death_id
                FROM actor_actor

                INNER JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
                INNER JOIN source_entry ON actor_actor.source_entry_id=source_entry.id

                WHERE role_personal.name='baptised' AND actor_id = #{params[:id]};")
        else
            cdr_result = client.query("SELECT NULL AS day_of_birth, NULL AS month_of_birth, NULL AS year_of_birth, NULL AS source_entry_birth_id,
                NULL AS day_of_death, NULL AS month_of_death, NULL AS year_of_death, NULL AS source_entry_death_id;")
        end
        cdr_result.first.to_json
    end


    # /actor/life_events/personal?id
    #       Returns the events throughout a persons life pertaining to their personal life
    #
    #       params
    #           id: The id of the actor
    #           source (optional): Specifies the reference source in which to search for the life events
    #
    #       return
    #           List of:
    #               source_entry_id: The id of the source entry which record this life event
    #               role: The role of the person in this entry
    #               place_id: The id of the place where this event happened
    #               place: The name of the place where this event happened
    #               number of mentions: The number of times someone was mentioned
    param :id, :Integer, required: true
    param :source, :String ,required: false
    get '/actor/life_events/personal' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        if params[:source].nil?
            cdr_result = client.query("SELECT actor_actor.source_entry_id, role_personal.name AS role, view_place.id AS place_id, view_place.place, actor_actor.number_of_mentions
            FROM actor_actor
            LEFT JOIN view_place ON actor_actor.place_id=view_place.id
            LEFT JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
            WHERE actor_actor.actor_id=#{params[:id]};")
        else
            cdr_result = client.query("SELECT actor_actor.source_entry_id, role_personal.name AS role, view_place.id AS place_id, view_place.place, actor_actor.number_of_mentions
            FROM actor_actor
            INNER JOIN source_entry ON source_entry_id=source_entry.id
            INNER JOIN source ON source_id = source.id
            LEFT JOIN view_place ON actor_actor.place_id=view_place.id
            LEFT JOIN role_personal ON actor_actor.role_personal_id=role_personal.id
            WHERE actor_actor.actor_id=#{params[:id]} AND source.reference = '#{params[:source]}';")
        end
        cdr_result.to_a.to_json
    end

    # /actor/life_events/professional?id
    #       Returns the events throughout a persons life pertaining to their professional life
    #
    #       params
    #           id: The id of the actor
    #           source (optional): Specifies a source in which to search for the life events
    #
    #       return
    #           List of:
    #               source_entry_id: The id of the entry in the source
    #               phase: The phase in which this entry is
    #               remarks: Any additional remarks
    #               role_organization: The role of the organization
    #               organization_id: The id of the organization
    #               organization_name: The name of the organization
    #               status: The status of the actor with the organization
    param :id, :Integer, required: true
    param :source, :String ,required: false
    get '/actor/life_events/professional' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        if params[:source].nil?
            cdr_result = client.query("SELECT actor_role.source_entry_id, actor_role.phase, actor_role.remarks,
            role_organization.name AS role_organization, organization.id AS organization_id, organization.name AS organization_name, status.name AS status
            FROM actor_role
            LEFT JOIN role_organization ON actor_role.role_organization_id=role_organization.id
            LEFT JOIN organization ON actor_role.organization_id=organization.id
            LEFT JOIN status ON actor_role.status_id=status.id
            WHERE actor_role.actor_id=#{params[:id]};")
        else
            cdr_result = client.query("SELECT actor_role.source_entry_id, actor_role.phase, actor_role.remarks,
                role_organization.name AS role_organization, organization.id AS organization_id, organization.name AS organization_name, status.name AS status
                FROM actor_role
                INNER JOIN source_entry ON source_entry_id=source_entry.id
                INNER JOIN source ON source_id = source.id
                LEFT JOIN role_organization ON actor_role.role_organization_id=role_organization.id
                LEFT JOIN organization ON actor_role.organization_id=organization.id
                LEFT JOIN status ON actor_role.status_id=status.id
                WHERE actor_role.actor_id=#{params[:id]} AND source.reference = '#{params[:source]}';")
        end
        cdr_result.to_a.to_json
    end

    # -------------------------------------------------- Relationships --------------------------------------------------
    #       Information pertaining to the relationships recorded in the sources.

    # /relationship/personal/spouses?id
    #       Returns the spouses of the person identified by the id
    #
    #       params
    #           id: The id of the actor whose spouse we are searching for
    #       return
    #           ListOf:
    #               id: The id of the spouse
    #               first_name: The first name of the spouse
    #               surname: The surname of the spouse
    #               source_entry_id: The id of the source entry, which recorded the spouse
    param :id, :Integer, required: true
    get '/relationship/personal/spouses' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
                    actor.id,
                    actor.first_name,
                    actor.surname,
                    source_entry.id AS source_entry_id
                FROM
                    actor_actor AS a_a1,
                    actor_actor AS a_a2,
                    actor,
                    source_entry
                WHERE
                    a_a1.actor_id =  #{params[:id]}  AND
                    a_a1.role_personal_id = 70 AND       -- Married
                    a_a2.role_personal_id = 70 AND       -- Married
                    a_a1.source_entry_id = source_entry.id AND
                    a_a2.source_entry_id = source_entry.id AND
                    actor.id = a_a2.actor_id AND actor.id != a_a1.actor_id;")
        cdr_result.to_a.to_json
    end

    # /relationship/personal/parents?id
    #       Return the parents of the person identified by the id
    #
    #       params
    #           id: The id of the actor whose parents we are searching for
    #
    #       return
    #           father_id: The id of the father
    #           father_first_name: The first name of the father
    #           father_surname: The surname of the father
    #           mother_id: The id of the mother
    #           mother_first_name: The first name of the mother
    #           mother_surname: The surname of the mother
    #           source_entry_id: The id of the source entry, which recorded these parents
    param :id, :Integer, required: true
    get '/relationship/personal/parents' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
            -- father
            a2.id AS father_id,
            a2.first_name AS father_first_name,
            a2.surname AS father_surname,
            -- mother
            a3.id AS mother_id,
            a3.first_name AS mother_first_name,
            a3.surname AS mother_surname,

            source_entry.id AS source_entry_id

            FROM
            -- baptism data
            source,
            source_entry
            JOIN actor AS a1
            JOIN actor_actor AS a_a1

            -- father
            LEFT JOIN actor_actor AS a_a2 ON (a_a2.source_entry_id = source_entry.id AND a_a2.role_personal_id = 48) -- 48 = father
            LEFT JOIN actor AS a2 ON (a_a2.actor_id = a2.id)
            -- mother
            LEFT JOIN actor_actor AS a_a3 ON (a_a3.source_entry_id = source_entry.id AND a_a3.role_personal_id = 71) -- 71 = mother
            LEFT JOIN actor AS a3 ON (a_a3.actor_id = a3.id)
            WHERE
            source.id = source_entry.source_id AND
            -- actor (baptized) information
            a1.id = #{params[:id]} AND
            source_entry.source_entry_type_id = 1 AND   -- 1 = baptism
            a_a1.source_entry_id = source_entry.id AND
            a_a1.actor_id = a1.id AND
            a_a1.role_personal_id = 8;                  -- 8 = baptised;")
        cdr_result.first.to_json
    end

    # /relationship/personal/offspring?id
    #       Returns the offspring of the person identified by the id
    #
    #       params
    #           id: The id of the actor whose offspring we are searching for
    #
    #       return
    #           List of:
    #               id: The id of the child
    #               first_name: The first name of the child
    #               surname: The surname of the child
    #               year_of_birth: The year in which the child was born, according to baptism records
    #               source_entry_id: The id of the source entry, which recorded this child
    param :id, :Integer, required: true
    get '/relationship/personal/offspring' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
                    actor.id,
                    actor.first_name,
                    actor.surname,
                    source_entry.date_year AS year_of_birth,
                    source_entry.id AS source_entry_id
                FROM
                    actor_actor AS a_a1,
                    actor_actor AS a_a2,
                    actor,
                    source_entry
                WHERE
                    a_a1.actor_id =  #{params[:id]}  AND
                    a_a1.role_personal_id IN (48, 71) AND       -- cited either as a father or a mother
                    a_a2.role_personal_id = 8 AND               -- baptized
                    a_a1.source_entry_id = source_entry.id AND
                    a_a2.source_entry_id = source_entry.id AND
                    actor.id = a_a2.actor_id;")
        cdr_result.to_a.to_json
    end

    # /relationship/personal/godparents?id
    #       Return the godparents of the person identified by the id
    #
    #       params
    #           id: The id of the actor whose godparents we are searching for
    #
    #       return
    #           godfather_id: The id of the godfather
    #           godfather_first_name: The first name of the godfather
    #           godfather_surname: The surname of the godfather
    #           godmother_id: The id of the godmother
    #           godmother_first_name: The first name of the godmother
    #           godmother_surname: The surname of the godmother
    #           source_entry_id: The id of the source entry, which recorded these godparents
    param :id, :Integer, required: true
    get '/relationship/personal/godparents' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
            -- godfather
            a2.id AS godfather_id,
            a2.first_name AS godfather_first_name,
            a2.surname AS godfather_surname,
            -- godmother
            a3.id AS godmother_id,
            a3.first_name AS godmother_first_name,
            a3.surname AS godmother_surname,

            source_entry.id AS source_entry_id

            FROM
            -- baptism data
            source,
            source_entry
            JOIN actor AS a1
            JOIN actor_actor AS a_a1

            -- godfather
            LEFT JOIN actor_actor AS a_a2 ON (a_a2.source_entry_id = source_entry.id AND a_a2.role_personal_id = 53) -- 53 = godfather
            LEFT JOIN actor AS a2 ON (a_a2.actor_id = a2.id)
            -- godmother
            LEFT JOIN actor_actor AS a_a3 ON (a_a3.source_entry_id = source_entry.id AND a_a3.role_personal_id = 55) -- 55 = godmother
            LEFT JOIN actor AS a3 ON (a_a3.actor_id = a3.id)
            WHERE
            source.id = source_entry.source_id AND
            -- actor (baptized) information
            a1.id = #{params[:id]} AND
            source_entry.source_entry_type_id = 1 AND   -- 1 = baptism
            a_a1.source_entry_id = source_entry.id AND
            a_a1.actor_id = a1.id AND
            a_a1.role_personal_id = 8;                  -- 8 = baptised")
        cdr_result.first.to_json
    end

    # /relationship/personal/godchildren?id
    #       Returns the godchildren of the person identified by the id
    #
    #       params
    #           id: The id of the actor whose godchildren we are searching for
    #
    #       return
    #           List of:
    #               id: The id of the godchild
    #               first_name: The first name of the godchild
    #               surname: The surname of the godchild
    #               year_of_birth: The year in which the godchild was born, according to baptism records
    #               source_entry_id: The id of the source entry, which recorded this godchild
    param :id, :Integer, required: true
    get '/relationship/personal/godchildren' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
                    actor.id,
                    actor.first_name,
                    actor.surname,
                    source_entry.date_year AS year_of_birth,
                    source_entry.id AS source_entry_id
                FROM
                    actor_actor AS a_a1,
                    actor_actor AS a_a2,
                    actor,
                    source_entry
                WHERE
                    a_a1.actor_id =  #{params[:id]}  AND
                    a_a1.role_personal_id IN (53, 55) AND       -- cited either as a godfather or a godmother
                    a_a2.role_personal_id = 8 AND               -- baptized
                    a_a1.source_entry_id = source_entry.id AND
                    a_a2.source_entry_id = source_entry.id AND
                    actor.id = a_a2.actor_id;")
        cdr_result.to_a.to_json
    end

    # /relationship/professional/teachers?id
    #       Returns the teachers of the actor identified by the id
    #
    #       params
    #           id: The id of the actor whose teachers we are searching for
    #
    #       return
    #           List of:
    #               id: The id of the teacher
    #               first_name: The first name of the teacher
    #               surname: The surname of the teacher
    #               year: The year in which the actor became an apprentice of this teacher
    #               source_entry_id: The id of the source entry, which recorded this teacher
    param :id, :Integer, required: true
    get '/relationship/professional/teachers' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
                    actor.id,
                    actor.first_name,
                    actor.surname,
                    source_entry.date_year AS year,
                    source_entry.id AS source_entry_id
                FROM
                    actor_role AS t1,
                    actor_role AS t2,
                    actor,
                    source_entry
                WHERE
                    t1.source_entry_id = source_entry.id AND
                    t2.source_entry_id = source_entry.id AND
                    t1.phase = 'start' AND
                    t1.status_id = 1 AND
                    t2.status_id = 14 AND
                    t1.actor_id = #{params[:id]} AND
                    t2.actor_id = actor.id;")
        cdr_result.to_a.to_json
    end

    # /relationship/professional/students?id
    #       Returns the students of the actor identified by the id
    #
    #       params
    #           id: The id of the actor whose students we are searching for
    #
    #       return
    #           List of:
    #               id: The id of the student
    #               first_name: The first name of the student
    #               surname: The surname of the student
    #               year: The year in which the actor became an teacher of this student
    #               source_entry_id: The id of the source entry, which recorded this student
    param :id, :Integer, required: true
    get '/relationship/professional/students' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT
                    actor.id,
                    actor.first_name,
                    actor.surname,
                    source_entry.date_year AS year,
                    source_entry.id AS source_entry_id
                FROM
                    actor_role AS t1,
                    actor_role AS t2,
                    actor,
                    source_entry
                WHERE
                    t1.source_entry_id = source_entry.id AND
                    t2.source_entry_id = source_entry.id AND
                    t1.phase = 'start' AND
                    t1.status_id = 14 AND
                    t2.status_id = 1 AND
                    t1.actor_id = #{params[:id]} AND
                    t2.actor_id = actor.id;")
        cdr_result.to_a.to_json
    end

    # /relationship/location/residents?id
    #       Returns the residents of a location
    #
    #       params
    #           id: The id of the place
    #
    #       return
    #           List Of:
    #               id: The id of the actor that resided at the place
    #               first_name: The name of the actor
    #               surname: The surname of the actor
    #               source_entry_id: The id of the source entry, which records this resident
    param :id, :Integer, required: true
    get '/relationship/location/residents' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source_entry_id, actor_id, actor.first_name, actor.surname
            FROM actor_place
            JOIN view_place ON view_place.id = place_id
            JOIN actor ON actor_id=actor.id
            JOIN role_place ON role_place_id=role_place.id
            WHERE role_place.name='resident' AND view_place.id = #{params[:id]};")
        cdr_result.to_a.to_json
    end

    # /relationship/location/living_places?id
    #       Returns the locations where the given actor lived
    #
    #       params
    #           id: The id of the actor
    #
    #       return
    #           List Of:
    #               id: The id of the place
    #               place_name = The name of the place
    #               source_entry_id: The id of the source entry, which records this living place
    param :id, :Integer, required: true
    get '/relationship/location/living_places' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source_entry_id, place_id, view_place.place AS place_name
            FROM actor_place
            JOIN view_place ON view_place.id = place_id
            JOIN actor ON actor_id=actor.id
            JOIN role_place ON role_place_id=role_place.id
            WHERE role_place.name='resident' AND actor_id = #{params[:id]};")
        cdr_result.to_a.to_json
    end

    # -------------------------------------------------- PLACE --------------------------------------------------
    #       Information on places

    # /place/id?name
    #       Returns the id of a place that matches the place name exactly.
    #
    #       params
    #           name: The name of the place
    #
    #       return
    #           id: The id of the given place name
    param :name, :String, required: true
    get '/place/id' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id FROM view_place WHERE place='#{params[:name]}';")
        cdr_result.first.to_json
    end

    # /place/search?name
    #       Returns a list of possible places that match the searched name
    #
    #       params
    #           name: The name to search for
    #
    #       return
    #           List of:
    #               id: The id of the possible place
    #               name: The full name of the the possible place
    param :name, :String, required: true
    get '/place/search' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id, place AS name FROM view_place WHERE place LIKE '%#{params[:name]}%';")
        cdr_result.to_a.to_json
    end

    # /place/info?id
    #       Returns the information of the place identified by the id.
    #
    #       params
    #           id: The id indicating the place
    #
    #       return
    #           place: The name of the place
    #           country: The name of the country, possibly null
    #           city: The name of the city, possibly null
    #           parish: The name of the parish, possibly null
    #           street: The name of the street, possibly null
    #           house: The name of the house, possibly null
    param :id, :Integer, required: true
    get '/place/info' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT place, country, city, parish, street, house
            FROM view_place
            WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end
    $place_info_dict = {'name'=>'place AS name', 'country'=>'country', 'city'=>'city', 'parish'=>'parish', 'street'=>'street', 'house'=>'house'}

    # /place/:place_type?id
    #       Returns the :place_type of the place identified by the id.
    #
    #       params
    #           id: The id indicating the place
    #
    #       return
    # TODO: Specify in docs
    #
    #           name: The name of the place
    #           country: The name of the country, possibly null
    #           city: The name of the city, possibly null
    #           parish: The name of the parish, possibly null
    #           street: The name of the street, possibly null
    #           house: The name of the house, possibly null
    param :id, :Integer, required: true
    get '/place/:place_type' do
        pass unless $place_info_dict.keys.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT #{$place_info_dict[params[:place_type]]}
            FROM view_place
            WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end

    # :place_type IN ('country', 'city', 'parish', 'street', 'house'), Different types of places
    $place_type_list = ['country', 'city', 'parish', 'street', 'house']

    # /place/:place_type/id?name
    #       Returns the ids of the :place_type which matches the name exactly.
    #
    #       params
    #           name: The name of the :place_type
    #
    #       return
    #           id: The :place_type id of the given :place_type name
    param :name, :String, required: true
    get '/place/:place_type/id' do
        pass unless $place_type_list.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id FROM #{params[:place_type]} WHERE name='#{params[:name]}';")
        cdr_result.first.to_json
    end

    # /place/:place_type/search?name
    #       Return the ids of the :place_type which matches the name partially or exactly
    #
    #       params
    #           name: The (partial) name of the :place_type
    #
    #       return
    #           List of:
    #               id: The id of the :place_types where the :place_type name matches
    #               name: The full name of the possible :place_type
    param :name, :String, required: true
    get '/place/:place_type/search' do
        pass unless $place_type_list.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id, name FROM #{params[:place_type]} WHERE name LIKE '%#{params[:name]}%';")
        cdr_result.to_a.to_json
    end

    # /place/:place_type/info?id
    #       Returns the information of the :place_type identified by the id.
    #
    #       params
    #           id: The id indicating the :place_type
    #
    #       return
    #           name: The name of the :place_type
    param :id, :Integer, required: true
    get '/place/:place_type/info' do
        pass unless $place_type_list.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT name FROM #{params[:place_type]} WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end


    # /place/:place_type/name?id
    #       Returns the name of the :place_type identified by the id.
    #
    #       params
    #           id: The id indicating the :place_type
    #
    #       return
    #           name: The name of the :place_type
    param :id, :Integer, required: true
    get '/place/:place_type/name' do
        pass unless $place_type_list.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT name FROM #{params[:place_type]} WHERE id=#{params[:id]};")
        cdr_result.first.to_json
    end


    # /place/:place_type/matching?id
    #       Returns the place which matches the :place_type id provided
    #
    #       params
    #           id: The id indicating the :place_type
    #
    #       return
    #           List of:
    #               id: The id of the place
    #               place: The name of the place
    #               country: The name of the country
    #               city: The name of the city
    #               parish: The name of the parish
    #               street: The name of the street
    #               house: The name of the house
    param :id, :Integer, required: true
    get '/place/:place_type/matching' do
        pass unless $place_type_list.include? params[:place_type]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT view_place.id, view_place.place, view_place.country, view_place.city, view_place.parish, view_place.street, view_place.house
            FROM view_place
            INNER JOIN place ON view_place.id = place.id
            WHERE place.#{params[:place_type]}_id=#{params[:id]};")
        cdr_result.to_a.to_json
    end

    # -------------------------------------------------- SOURCE ENTRY --------------------------------------------------
    #       Information related to the entries in sources

    # /source_entry/id?source_reference&entry_reference
    #       Returns the id of the source entry exactly matching the source and entry reference
    #
    #       params
    #           source_reference: The reference of the source
    #           entry_reference: The reference of the entry in the source
    #
    #       return
    #           id: The id exactly matching these references
    param :source_reference, :String, required: true
    param :entry_reference, :String, required: true
    get '/source_entry/id' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source_entry.id
            FROM source_entry
            JOIN source ON source_id=source.id
            WHERE source.reference = '#{params[:source_reference]}' AND source_entry.reference = '#{params[:entry_reference]}';")
        cdr_result.first.to_json
    end

    # /source_entry/search?source_reference&entry_reference
    #       Returns a list of source entries matching the provided references
    #
    #       params
    #           source_reference: A partial reference of the source
    #           entry_reference: A partial reference of the entry in the source
    #
    #       return
    #           List Of:
    #               id: The id of a matching source entry
    #               entry_reference: the reference of the matching entry
    #               source_reference: the reference of the source in which the entry is recorded
    param :source_reference, :String, required: true
    param :entry_reference, :String, required: true
    get '/source_entry/search' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source_entry.id, source_entry.reference AS entry_reference, source.reference AS source_reference
            FROM source_entry
            JOIN source ON source_id=source.id
            WHERE source.reference LIKE '%#{params[:source_reference]}%' AND source_entry.reference LIKE '%#{params[:entry_reference]}%';")
        cdr_result.to_a.to_json
    end


    # /source_entry/info?id
    #       Returns the info of the source entry
    #
    #       params
    #           id: The id of the source entry
    #
    #       return
    #           source_id: The id of the source where
    #           source_reference: The reference of the source
    #           source_entry_reference: The reference of the entry in the source
    #           source_entry_type_name: The name of the type of entry
    #           source_entry_type_category: The category of the type of entry
    #           date_day: The day of the entry
    #           date_month: The month of the entry
    #           date_year: the year of the entry
    #           remarks: Any remarks for the entry
    #           picture_file: The file containing the picture of the entry
    #           publication: The publication linked to this entry
    #
    #           TODO: crud user not included for privacy reasons?
    #           TODO: ghost?
    param :id, :Integer, required: true
    get '/source_entry/info' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source_id, source.reference AS source_reference, source_entry.reference AS source_entry_reference,
            source_entry_type.name AS source_entry_type_name, source_entry_type.category AS source_entry_type_category,
            date_day, date_month, date_year,
            source_entry.remarks, picture_file, publication.description AS publication
            FROM source_entry
            JOIN source_entry_type ON source_entry_type_id=source_entry_type.id
            JOIN source ON source_id=source.id
            LEFT JOIN publication ON publication_id=publication.id
            WHERE source_entry.id=#{params[:id]};")
        cdr_result.first.to_json
    end


    $source_entry_info_dict = {"source_id" => "source_id", "source_reference" => "source.reference AS source_reference",
                               "source_entry_reference" => "source_entry.reference AS source_entry_reference",
                               "source_entry_type_name" => "source_entry_type.name AS source_entry_type_name",
                               "source_entry_type_category" => "source_entry_type.category AS source_entry_type_category",
                               "date" => "date_day, date_month, date_year",
                               "remarks" => "source_entry.remarks", "picture_file" => "picture_file",
                               "publication" => "publication.description AS publication"}


    # /source_entry/:se_info?id
    #       Returns the :se_info of the source entry
    #
    #       params
    #           id: The id of the source entry
    #
    #       return
    # TODO: fix in docs
    #
    #           source_id: The id of the source where
    #           source_reference: The reference of the source
    #           source_entry_reference: The reference of the entry in the source
    #           source_entry_type_name: The name of the type of entry
    #           source_entry_type_category: The category of the type of entry
    #           date_day: The day of the entry
    #           date_month: The month of the entry
    #           date_year: the year of the entry
    #           remarks: Any remarks for the entry
    #           picture_file: The file containing the picture of the entry
    #           publication: The publication linked to this entry
    #
    #           TODO: crud user not included for privacy reasons?
    #           TODO: ghost?
    param :id, :Integer, required: true
    get '/source_entry/:se_info' do
        pass unless $source_entry_info_dict.keys.include? params[:se_info]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT #{$source_entry_info_dict[params[:se_info]]}
            FROM source_entry
            JOIN source_entry_type ON source_entry_type_id=source_entry_type.id
            JOIN source ON source_id=source.id
            LEFT JOIN publication ON publication_id=publication.id
            WHERE source_entry.id=#{params[:id]};")
        cdr_result.first.to_json
    end


    #-------------------------------------------------- Source ------------------------------------------------
    #       Information on the source

    # /source/id?reference
    #       Returns the id of the source matching the reference exactly.
    #
    #       params
    #           reference: The reference of the source
    #
    #       return
    #           id: The id of the source that matches the reference
    param :reference, :String, required: true
    get '/source/id' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source.id
            FROM source
            WHERE source.reference = '#{params[:reference]}';")
        cdr_result.first.to_json
    end

    # /source/search?reference
    #       Returns a list of sources matching the provided reference at least partially.
    #
    #       params
    #           reference: The reference of the source
    #
    #       return
    #           List Of:
    #               id: The id of the source that matches the reference at least partially
    #               reference: The full reference of the source
    param :reference, :String, required: true
    get '/source/search' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source.id, source.reference
            FROM source
            WHERE source.reference LIKE '%#{params[:reference]}%';")
        cdr_result.to_a.to_json
    end


    # /source/info?id
    #       Returns information about the source identified by the given id.
    #
    #       params
    #           id: The id of the source
    #
    #       return
    #           reference: The reference used for the source, constructed from an abbreviation of the archive name, the archival_set_abbreviation and the call number
    #           call_number: the call number of the source
    #           archive: The abbreviation and the name of the archive containing this source, separated by "|"
    #           archival_set_abbreviation: The abbreviation of the archival set containing this source
    #           archival_set_name: The name of the archival set containing this source
    param :id, :Integer, required:true
    get '/source/info' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT source.reference, source.call_number,
            archive.name AS archive,
            archival_set.name AS archival_set_abbreviation, archival_set.remarks AS archival_set_name
            FROM source
            INNER JOIN archive ON archive_id=archive.id
            INNER JOIN archival_set ON archival_set_id= archival_set.id
            WHERE source.id = #{params[:id]};")
        cdr_result.first.to_json
    end


    $source_info_dict = {"reference" => "source.reference", "call_number" => "source.call_number",
                         "archive" => "archive.name AS archive",
                         "archival_set_abbreviation" => "archival_set.name AS archival_set_abbreviation",
                         "archival_set_name" => "archival_set.remarks AS archival_set_name"}

    # /source/:source_info?id
    #       Returns :source_info of the source identified by the given id.
    #
    #       params
    #           id: The id of the source
    #
    #       return
    # TODO: Fix in docs
    #
    #           reference: The reference used for the source, constructed from an abbreviation of the archive name, the archival_set_abbreviation and the call number
    #           call_number: the call number of the source
    #           archive: The abbreviation and the name of the archive containing this source, separated by "|"
    #           archival_set_abbreviation: The abbreviation of the archival set containing this source
    #           archival_set_name: The name of the archival set containing this source
    param :id, :Integer, required:true
    get '/source/:source_info' do
        pass unless $source_info_dict.keys.include? params[:source_info]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT #{$source_info_dict[params[:source_info]]}
            FROM source
            INNER JOIN archive ON archive_id=archive.id
            INNER JOIN archival_set ON archival_set_id= archival_set.id
            WHERE source.id = '#{params[:id]}';")
        cdr_result.first.to_json
    end


    #-------------------------------------------------- Organization ------------------------------------------------
    #       Information on organizations

    # /organization/id?name
    #       Returns the ids of organizations matching the name exactly
    #
    #       params
    #           name: The name of the organization
    #
    #       return
    #           List Of:
    #               id: The id of the organization matching the name exactly
    param :name, :String, required: true
    get '/organization/id' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id FROM organization WHERE name='#{params[:name]}';")
        cdr_result.to_a.to_json
    end

    # /organization/search?name
    #       Returns the ids of organizations matching the name at least partially
    #
    #       params
    #           name: The name partially matching the organization
    #
    #       return
    #           List Of:
    #               id: The id of the organization partially matching the name
    #               name: The name of the organization
    param :name, :String, required: true
    get '/organization/search' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT id, name FROM organization WHERE name LIKE '%#{params[:name]}%';")
        cdr_result.to_a.to_json
    end

    # /organization/info?id
    #       Returns the information about the organization identified by the given id.
    #
    #       params
    #           id: The id of the organization
    #
    #       return
    #           name: name of the organization
    #           organization_type_name: The type of the organization
    #           place_id: The id of the place of the organization
    #           place_name: The name of the place of the organization
    #           actor_id: The id of the actor associated with the organization
    #           first_name: The first name of the actor associated with the organization
    #           surname: The surname of the actor associated with the organization
    param :id, :Integer, required: true
    get '/organization/info' do
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT organization.name, organization_type.name AS organization_type_name,
            place_id, place AS place_name,
            actor_id, actor.first_name, actor.surname
            FROM organization
            JOIN organization_type ON organization_type_id=organization_type.id
            JOIN view_place ON place_id=view_place.id
            LEFT JOIN actor ON actor_id=actor.id
            WHERE organization.id = #{params[:id]};")
        cdr_result.first.to_json
    end

    $organization_info_dict = {"name" => "organization.name","organization_type_name" => "organization_type.name AS organization_type_name",
                               "place_id" => "place_id", "place_name" => "place AS place_name",
                               "actor_id" => "actor_id", "first_name" => "actor.first_name", "surname" => "actor.surname"}

    # /organization/:org_info?id
    #       Returns the :org_info of the organization identified by the given id.
    #
    #       params
    #           id: The id of the organization
    #
    #       return
    # TODO: Fix in docs
    #
    #           name: name of the organization
    #           organization_type_name: The type of the organization
    #           place_id: The id of the place of the organization
    #           place_name: The name of the place of the organization
    #           actor_id: The id of the actor associated with the organization
    #           first_name: The first name of the actor associated with the organization
    #           surname: The surname of the actor associated with the organization
    param :id, :Integer, required: true
    get '/organization/:org_info' do
        pass unless $organization_info_dict.keys.include? params[:org_info]
        client = Mysql2::Client.new(:host => $db_host, :port => $db_port, :username => $db_user, :password => $db_pass, :database => $db_name)
        cdr_result = client.query("SELECT #{$organization_info_dict[params[:org_info]]}
            FROM organization
            JOIN organization_type ON organization_type_id=organization_type.id
            JOIN view_place ON place_id=view_place.id
            LEFT JOIN actor ON actor_id=actor.id
            WHERE organization.id = #{params[:id]};")
        cdr_result.first.to_json
    end


    error Sinatra::NotFound do
        halt 404, 'Not found, please consult the docs!'
    end

end
