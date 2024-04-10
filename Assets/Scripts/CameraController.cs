using UnityEngine;

public class CameraController : MonoBehaviour
{
    public Transform pivot;                      // �ֶ���ӣ������ٵĶ���pivot������ʲôΪ��
    public Vector3 pivotOffset = Vector3.zero; // ��Ŀ���ƫ����
    public Transform target;                     // ��һ����ѡ�еĶ���(���ڼ��cam��target֮��Ķ���)
    public float distance = 10.0f;     // ��Ŀ�����(ʹ�ñ佹)
    public float minDistance = 2f;        //��С����
    public float maxDistance = 15f;       //������
    public float zoomSpeed = 1f;        //�ٶȱ���
    public float xSpeed = 250.0f;    //x�ٶ�
    public float ySpeed = 120.0f;    //y�ٶ�
    public bool allowYTilt = true;      //����Y����б
    public float yMinLimit = -90f;      //����������Ƕ�
    public float yMaxLimit = 90f;       //����������Ƕ�
    private float x = 0.0f;      //x����
    private float y = 0.0f;      //y����
    private float targetX = 0f;        //Ŀ��x
    private float targetY = 0f;        //Ŀ��y
    private float targetDistance = 0f;        //Ŀ�����
    private float xVelocity = 1f;        //x�ٶ�
    private float yVelocity = 1f;        //y�ٶ�
    private float zoomVelocity = 1f;        //�ٶȱ���


    void Start()
    {
        var angles = transform.eulerAngles;                          //��ǰ��ŷ����
        targetX = x = angles.x;                                   //��x����Ŀ��x��ֵ
        targetY = y = ClampAngle(angles.y, yMinLimit, yMaxLimit); //�޶���������ϣ�����֮���ֵ�����ظ���y��Ŀ��y
        targetDistance = distance;                                       //��ʼ��������Ϊ10��
    }


    void LateUpdate()
    {
        if (pivot) //��������趨��Ŀ��
        {
            float scroll = Input.GetAxis("Mouse ScrollWheel"); //��ȡ������
            //�������0��˵�������ˣ���ô��Ŀ����룬�ͼ��ٹ̶�����1��������ǰ�������ͼ���ֵ����ʹԽ��Խ��
            if (scroll > 0.0f) targetDistance -= zoomSpeed;
            else if (scroll < 0.0f) targetDistance += zoomSpeed;        //�����Զ             //����
            targetDistance = Mathf.Clamp(targetDistance, minDistance, maxDistance);      //Ŀ��ľ����޶���2-15֮��
            if (Input.GetMouseButton(1) || Input.GetMouseButton(0) && (Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl))) //����Ҽ�
            {
                targetX += Input.GetAxis("Mouse X") * xSpeed * 0.02f; //Ŀ���x�������x�ƶ�*5
                if (allowYTilt)                                       //y��������б
                {
                    targetY -= Input.GetAxis("Mouse Y") * ySpeed * 0.02f; //Ŀ���y�������y�ƶ�*2.4
                    targetY = ClampAngle(targetY, yMinLimit, yMaxLimit); //����y���ƶ���Χ��-90��90֮��
                }
            }
            #region ʹ����ƽ����ֵ
            x = Mathf.SmoothDampAngle(x, targetX, ref xVelocity, 0.3f);  //ʹ����ƽ����ֵ
            if (allowYTilt) y = Mathf.SmoothDampAngle(y, targetY, ref yVelocity, 0.3f);
            else y = targetY;
            Quaternion rotation = Quaternion.Euler(y, x, 0);
            distance = Mathf.SmoothDamp(distance, targetDistance, ref zoomVelocity, 0.5f);
            Vector3 position = rotation * new Vector3(0.0f, 0.0f, -distance) + pivot.position + pivotOffset;
            transform.rotation = rotation;
            transform.position = position;
            #endregion

            #region ��ʹ��ƽ����ֵ
            //targetY = ClampAngle(targetY, yMinLimit, yMaxLimit);
            //Quaternion rotation1 = Quaternion.Euler(targetY, targetX, 0);
            //distance = Mathf.SmoothDamp(distance, targetDistance, ref zoomVelocity, 0f);
            //Vector3 position1 = rotation1 * new Vector3(0.0f, 0.0f, -distance) + pivot.position + pivotOffset;
            //transform.rotation = rotation1;
            //transform.position = position1; 
            #endregion
        }
    }


    /// <summary>
    /// �޶�һ��ֵ������С�������֮�䣬������
    /// </summary>
    /// <param name="angle"></param>
    /// <param name="min"></param>
    /// <param name="max"></param>
    /// <returns></returns>
    private float ClampAngle(float angle, float min, float max)
    {
        if (angle < -360) angle += 360;
        if (angle > 360) angle -= 360;
        return Mathf.Clamp(angle, min, max);
    }
}