import streamlit as st
import sys
print(sys.executable)
import psycopg2

# Connect to the PostgreSQL database
conn = psycopg2.connect(
    dbname="project",
    user="postgres",
    password="Vishnu-2526",
    host="localhost",
    port="5432"
)

# Function to execute SQL queries
def execute_query(query):
    cursor = conn.cursor()
    cursor.execute(query)
    conn.commit()
    cursor.close()

# Function to fetch data from the database
def fetch_data(query):
    cursor = conn.cursor()
    cursor.execute(query)
    data = cursor.fetchall()
    cursor.close()
    return data

# Streamlit UI
def main():
    st.title("PostgreSQL Database Frontend")
    st.sidebar.title("Navigation")
    page = st.sidebar.selectbox("Select Page", ["Home", "View Data", "Add User"])

    if page == "Home":
        st.write("Welcome to the PostgreSQL Database Frontend!")

    elif page == "View Data":
        st.header("View Data")
        table_name = st.text_input("Enter table name:")
        if table_name:
            query = f"SELECT * FROM {table_name};"
            data = fetch_data(query)
            st.write(data)

    elif page == "Add User":
        st.header("Add User")
        u_id = st.text_input("Enter user ID:")
        name = st.text_input("Enter user name:")
        if st.button("Add"):
            query = f"INSERT INTO acc (u_id, name) VALUES ({u_id}, '{name}');"
            execute_query(query)
            st.success("User added successfully!")

if __name__ == "_main_":
    main()