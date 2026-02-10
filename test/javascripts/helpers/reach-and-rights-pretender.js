export default function (helpers) {
  const { response } = helpers;

  this.get("/c/1/permissions", () =>
    response({
      category_id: 1,
      group_permissions: [
        {
          permission_type: 2,
          permission: "create_post",
          group_name: "staff",
          group_id: 3,
        },
      ],
    })
  );
}
