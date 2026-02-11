1. Primative version control 
    - Manual copy --> inefficient and error-prone.
    - chaos from manual backups(have many backups).
2. Why Git is needed 
    - Trcked changes in files and data that is immutable.
    - Maintains a history of who, what, when.
    - every commit is content-addressed (hash).
    - Enables easy roolback to stable version.
3. Set up User
    - `git config --global user.name "Name" ` 
    - `git config --global user.email "example@email.com"`
    - These two command use to set up user to identify who is commit and who is author.
4. Three git areas
    - 1. Working Tree (Working Directory) real file on disk that editable.
    - 2. Stageing Area (Index) prepares snapshot to be commited. 
    - 3. Git Directory (Repository, Local Repo) stored in .git that contain snapshot with unique hash
        Commit does NOT read from Working Directory. It reads only from Index.
5. Checking progress
    - `git status` --> show file states (modified, staged)
    - Recommended use before commit.
6. Making commit
    - `git commit` --> saves current snapshot that in staged area this will open nano editor to
        assign commit message save it will creates a new commit object and moves the current branch pointer.
    - use git commit -m "commit message" for quick commits.
    - Each commit points to its parent commit, forming a linked history chain.
7. Git log
    - `git log` --> show commits with author, date, and commit message.
    - `git log --oneline` --> show only hash of each commit and commit message.
8. Pointer in git log
    - [Branch_name] = pointer to the latest commit in that branch.
    - HEAD = pointer to the currently checked-out branch(in use).
    - {HEAD → branch → commit}