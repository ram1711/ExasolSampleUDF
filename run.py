import ssl
import time
import pyexasol

from rich.table import Table
from rich.align import Align
from rich.panel import Panel
from rich.status import Status
from rich.console import Console

console = Console()

header_text = "[bold cyan]Exasol GitHub UDF Test[/bold cyan]"
console.print(Align.center(Panel(header_text, border_style="blue", expand=False)))

with console.status("[bold green]Creating pyexasol connection...", spinner="dots") as status:
    dsn = '127.0.0.1:8563'
    conn = pyexasol.connect(
        dsn=dsn, user='sys', password='exasol',
        encryption=True, websocket_sslopt={'cert_reqs': ssl.CERT_NONE}
    )
    console.log("Connection established")
with console.status("[bold green]Setting up schema and table...", spinner="dots") as status:
    conn.execute('DROP SCHEMA IF EXISTS UDF_TEST CASCADE;')
    conn.execute('CREATE SCHEMA UDF_TEST;')
    conn.execute('CREATE TABLE UDF_TEST.REPOS (ORG VARCHAR(50), REPO VARCHAR(50));')
    conn.execute("INSERT INTO UDF_TEST.REPOS VALUES ('exasol', 'advanced-analytic-framework'), ('exasol', 'bucketfs-java'), ('exasol', 'compatibility-test-suite'), ('exasol', 'docker-db'), ('exasol', 'exasol-virtual-schema');")
    time.sleep(4)
    console.log("Schema and Table ready")

with console.status("[bold green]Creating UDF...", spinner="dots") as status:
    udf_code = r'''
import urllib.request, json

def run(ctx):
    org = ctx.ORG
    repo = ctx.REPO
    try:
        url = f"https://api.github.com/repos/{org}/{repo}/releases/latest"
        req = urllib.request.Request(url)
        req.add_header("User-Agent", "Exasol-Test")
        
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            date = data.get("published_at", "")[0:10]
            ver = data.get("tag_name", "")
            ctx.emit(org, repo, date, ver)
    except:
        ctx.emit(org, repo, None, None)
'''
    conn.execute(f'''
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UDF_TEST.GITHUB_UDF(
    ORG VARCHAR(50), REPO VARCHAR(50)
) EMITS (ORG VARCHAR(50), REPO VARCHAR(50), REL_DATE VARCHAR(50), REL_VER VARCHAR(50)) AS
{udf_code}
/
''')
    time.sleep(4)
    console.log("Exasol UDF created & executed")

console.print("\n[bold underline white]Input Table[/bold underline white]")

try:
    with console.status("[bold green]Setting up input table...", spinner="dots") as status:
        query = "SELECT UDF_TEST.GITHUB_UDF(ORG, REPO) FROM UDF_TEST.REPOS"
        repo_query = "SELECT * FROM UDF_TEST.REPOS"
        repo_results = conn.execute(repo_query).fetchall()
        time.sleep(4)
        repo_table = Table(show_header=True, header_style="bold magenta", border_style="bright_black")
        repo_table.add_column("Organization", style="cyan")
        repo_table.add_column("Repository", style="yellow")
        for org, repo in repo_results:
            repo_table.add_row(org, repo)
        console.print(repo_table)
        console.print(f"\n[bold green]✔ Done![/bold green] Processing  {len(repo_results)} repositories.\n")
except Exception as e:
    console.log(f"[bold red]ERROR:[/bold red] {e}")

try:
    with console.status("[bold green]Generating output table...", spinner="dots") as status:
        results = conn.execute(query).fetchall()
        console.print("\n[bold underline white]Output Table[/bold underline white]")
        table = Table(show_header=True, header_style="bold magenta", border_style="bright_black")
        table.add_column("Organization", style="cyan")
        table.add_column("Repository", style="yellow")
        table.add_column("Latest Release Date", justify="center", style="green")
        table.add_column("Latest Release Version", justify="right", style="bold white")
        for row in results:
            org, repo, date, ver = row
            display_date = date if date else "[red]N/A[/red]"
            display_ver = ver if ver else "[red]Error[/red]"
            table.add_row(org, repo, display_date, display_ver)
        console.print(table)
        console.print(f"\n[bold green]✔ Done![/bold green] Processed {len(results)} repositories.\n")
except Exception as e:
    console.log(f"[bold red]ERROR:[/bold red] {e}")

conn.close()