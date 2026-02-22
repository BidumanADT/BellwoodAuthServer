using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BellwoodAuthServer.Migrations
{
    public partial class AddAuthAuditEvents : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AuthAuditEvents",
                columns: table => new
                {
                    Id = table.Column<long>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    TimestampUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Username = table.Column<string>(type: "TEXT", maxLength: 256, nullable: true),
                    Action = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    Result = table.Column<string>(type: "TEXT", maxLength: 50, nullable: false),
                    CorrelationId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: true),
                    IpAddress = table.Column<string>(type: "TEXT", maxLength: 64, nullable: true),
                    UserAgent = table.Column<string>(type: "TEXT", maxLength: 512, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuthAuditEvents", x => x.Id);
                });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AuthAuditEvents");
        }
    }
}
