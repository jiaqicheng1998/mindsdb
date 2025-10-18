CREATE DATABASE banking_postgres_db
WITH ENGINE = 'postgres',
PARAMETERS = {
    "host": "host.docker.internal",
    "port": 5432,
    "database": "demo",
    "user": "postgresql",
    "password": "psqlpasswd",
    "schema": "demo_data"
};


CREATE ML_ENGINE openai_engine
FROM openai
USING
    openai_api_key = '';

SELECT * FROM information_schema.ml_engines WHERE name = 'openai_engine';

CREATE AGENT classification_agent
USING
    data = {
        "tables": ["banking_postgres_db.conversations_summary"]
    },
    prompt_template = '',
    timeout = 30;

-- suggest that we set the response format as JSON for easier parsing later
CREATE AGENT test_agent
USING
    data = {
        "tables": ["banking_postgres_db.conversations_summary"]
    },
    prompt_template= 'You are a banking customer service analyst. Analyze the conversation transcript and provide:

1. A concise summary (2-3 sentences) of the customer interaction
2. Classification of issue resolution status

IMPORTANT GUIDELINES:
- If the customer explicitly confirms the issue is resolved, mark as RESOLVED
- If the conversation ends without clear resolution, mark as UNRESOLVED
- If customer audio is missing or incomplete (e.g., only agent responses visible), mark as UNRESOLVED
- If the agent offers a solution but customer confirmation is missing, mark as UNRESOLVED
- If the conversation is cut off or incomplete, mark as UNRESOLVED
- Look for explicit confirmation words like "thank you", "that worked", "issue resolved", "problem solved"

Format your response EXACTLY as:
Summary: [your 2-3 sentence summary describing what happened in the conversation]
Status: [RESOLVED or UNRESOLVED]

Conversation to analyze:',
    timeout = 30;


SELECT answer
FROM test_agent 
WHERE question = '
client: Hi, I\'m calling to inquire about donating to a local charity through Union Financial. Can you help me with that? agent: Ofsolutely, Roseann! I have a few options for charating to charities through our bank. Can you tell me a little bit more about what you\'re looking to? Are you interested in making a one-time donation or setting up a recurring contribution? client: Well, I\'d like to make a one-time donation., but also set up a recurring monthly contributionation as Is that possible? agent: Yes, definitely\'s definitely possible. We me walk you through our process real quick. First, we have a list of pre-approved charities that we work with. Would you like me to send that over to you via email? client: That would be great, thank you! agent: Great. I\'ll send that over right away. Once you\'ve selected the charity you\'d like to don, we can set up the donation. For a one-time donation, we can process that immediately. For the recurring monthly donation, we\'ll need to set up an automatic transfer from your Union Financial account to the charity\'s account. Is that sound good to you? client: Yes, that sounds perfect. How do I go about selecting the charity? agent: Like I mentioned earlier, we have a list of pre-approved charities that we work with. You can review that list and let me know which charity you\'d like to support. If the charity you\'re interested in isn\'t on the list, we can still process the donation, it might take a little longer because we\'ll need to verify some additional information. client: Okay, I see. I think I\'d like to donate to the local animal shelter. They\'re not on the list, but I\'m sure they\'re legitimate. Can we still donate to them? agent: Absolutely! We can definitely still process the donation. the animal shelter. I\'ll just need to collect a bit more information from you to ensure everything goes smoothly. Can you please provide me with the charity\'s name and address? client: Sure! The name of the shelter is PPaws and Claws" and their address is 123 Main Street. agent: Perfect, I\'ve got all the information I need. I\'ll go ahead and process the don-time donation and set up the recurring monthly transfer. Is there anything else I can assist you with today, Roseann? client: No, that\'s all for now. Thank you so much for your help, Guadalupe! agent: You\'re very welcome, Roseann! It was my pleasure to assist you. Just to summary, we\'ve processed up a one-time donation to "aws and Claws Animal Shelter and a recurring monthly transfer to the same organization. Is there anything else I can do you with today? client: Nope, that\'s it! Thanks again! agent: You\'re welcome, Roseann. Have a wonderful day!';


    
SHOW AGENTS;

show SKILLS;

CREATE JOB process_new_conversations (

    UPDATE banking_postgres_db.conversations_summary
    SET
        summary = (
            SELECT answer
            FROM classification_agent
            WHERE question = banking_postgres_db.conversations_summary.conversation_text
            LIMIT 1
        ),
        resolved = CASE
            WHEN (
                SELECT answer
                FROM classification_agent
                WHERE question = banking_postgres_db.conversations_summary.conversation_text
                LIMIT 1
            ) LIKE '%Status: RESOLVED%' THEN TRUE
            ELSE FALSE
        END
    WHERE
        banking_postgres_db.conversations_summary.summary IS NULL
)
EVERY 1 min;


show JOBS;
DROP JOB process_new_conversations;

SHOW TRIGGERS;

-- SELECT conversation_id, conversation_text
-- FROM banking_postgres_db.conversations_summary
-- WHERE conversation_id > LAST;

-- create new job process_new_conversations (
--     -- create view latest_conversation
--     DROP VIEW IF EXISTS latest_conversation;
--     CREATE VIEW latest_conversation AS
--     SELECT 
--         conversation_id,
--         conversation_text,
--         created_at
--     FROM my_postgres.conversations_summary
--     ORDER BY created_at DESC
--     LIMIT 1;

--     -- create view laterst_agent_answer
--     SELECT answer
--     FROM your_agent_name
--     WHERE question = latest_conversation.conversation_text;
--     DROP VIEW IF EXISTS latest_agent_answer;
--     CREATE VIEW agent_results_view AS
-- SELECT 
--     json_extract(a.answer, '$.summary') AS summary,
--     CASE 
--         WHEN UPPER(json_extract(a.answer, '$.resolved')) = 'TRUE' THEN TRUE
--         ELSE FALSE
--     END AS resolved
-- FROM latest_conversation AS lc
-- JOIN your_agent_name AS a
-- WHERE a.question = lc.conversation_text;


--     -- insert into conversations_summary_only
--     INSERT INTO my_postgres.summary (conversation_id, summary_text, resolved)
--     SELECT 
--         conversation_id,
--         summary_text,
--         resolved
--     FROM latest_agent_answer
--     WHERE conversation_id NOT IN (
--         SELECT conversation_id 
--         FROM my_postgres.summary
--     );
-- )


-- another way 
-- CREATE JOB process_new_conversations (
    
--     -- Process and insert in one go using CTEs
--     INSERT INTO my_postgres.summary (conversation_id, summary_text, resolved)
--     WITH latest_conversation AS (
--         -- Get newest conversation
--         SELECT 
--             conversation_id,
--             conversation_text,
--             created_at
--         FROM my_postgres.conversations_summary
--         ORDER BY created_at DESC
--         LIMIT 1
--     ),
--     agent_answer AS (
--         -- Get agent's response
--         SELECT 
--             lc.conversation_id,
--             m.response as agent_response
--         FROM latest_conversation lc
--         CROSS JOIN LATERAL (
--             SELECT response
--             FROM my_ai_model
--             WHERE conversation_text = lc.conversation_text
--         ) m
--     )
--     -- Parse and insert
--     SELECT 
--         conversation_id,
--         -- Extract summary text
--         TRIM(REGEXP_REPLACE(agent_response, '.*Summary: (.*)', '\1', 's')) as summary_text,
--         -- Extract resolved status
--         CASE 
--             WHEN agent_response LIKE '%Status: RESOLVED%' THEN true
--             WHEN agent_response LIKE '%Status: UNRESOLVED%' THEN false
--             ELSE null
--         END as resolved
--     FROM agent_answer
--     WHERE conversation_id NOT IN (
--         SELECT conversation_id FROM my_postgres.summary
--     );

-- )
-- EVERY 10 minutes;  -- Adjust frequency as needed





-- DROP JOB IF EXISTS fill_conversation_summaries_cache;
-- CREATE JOB fill_conversation_summaries_cache (
--     INSERT INTO demo_data.conversation_summaries_cache (
--         id,
--         conversation_text,
--         summary,
--         resolved
--     )
--     SELECT
--         cs.id,
--         cs.conversation_text,
--         MAX(ca.answer) AS summary,
--         MAX(CASE WHEN ca.answer LIKE '%Status: RESOLVED%' THEN TRUE ELSE FALSE END) AS resolved
--     FROM demo_data.conversations_summary cs
--     JOIN classification_agent ca
--       ON ca.question = cs.conversation_text
--     LEFT JOIN demo_data.conversation_summaries_cache cache
--       ON cache.id = cs.id
--     WHERE cs.summary IS NULL
--       AND cache.id IS NULL
--     GROUP BY cs.id, cs.conversation_text
-- )
-- EVERY 1 MIN;

-- connect to confluence
CREATE DATABASE my_Confluence   
WITH ENGINE = 'confluence',
PARAMETERS = {
  "api_base": "https://jiaqicheng1998.atlassian.net",
  "username": "jiaqicheng1998@gmail.com",
  "password":""
};

-- create knowledge base
CREATE KNOWLEDGE_BASE my_confluence_kb
USING
    embedding_model = {
        "provider": "openai",
        "model_name": "text-embedding-3-small",
        "api_key":""
    },
    content_columns = ['body_storage_value'],
    id_column = 'id';

DESCRIBE KNOWLEDGE_BASE my_confluence_kb;

INSERT INTO my_confluence_kb (
    SELECT id, title, body_storage_value
    FROM my_confluence.pages
    WHERE id IN ('360449','589825')
);

-- verify data inserted
SELECT COUNT(*) as total_rows FROM my_confluence_kb;

SELECT * FROM my_confluence_kb
WHERE chunk_content = 'Consumer Focus'
LIMIT 3;