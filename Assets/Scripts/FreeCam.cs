using UnityEngine;
using UnityEngine.EventSystems;

public enum CamViewMode
{
    FREE,//自由视角
    TOP,//俯视角
    LIMIT//固定视角
}
public class FreeCam : MonoBehaviour
{
    //相机物体
    private Transform camTrans;

    /// <summary>
    /// 是否是第一次点击
    /// </summary>
    private bool _isFirstClick = true;

    /// <summary>
    /// 相机视角模式
    /// </summary>
    public CamViewMode viewMode = CamViewMode.FREE;

    [SerializeField]
    private Vector3 _resetTrans;//相机重置位置
    [SerializeField]
    private Vector3 _resetAngles;//相机重置角度

    [Header("键盘移动速度")]
    public float m_speed = 3f;
    [Header("鼠标中键移动速度")]
    public float m_mSpeed = 0.5f;
    [Header("旋转速度")]
    public float m_rSpeed = 5f;
    [Header("缩放速度")]
    public float m_sSpeed = 5f;
    [Header("最大缩放距离")]
    public float m_maxDistance = 10f;
    [Header("中键移动的缓动值")]
    public float moveSmoothing = 0.2f;

    private float m_deltX = 0f;//计算右键旋转
    private float m_deltY = 0f;//计算右键旋转

    void Start()
    {
        camTrans = transform;
    }
    void Update()
    {
        //在UI上时不执行
        //if (EventSystem.current.IsPointerOverGameObject()) return;

        if (viewMode != CamViewMode.LIMIT)
        {
            //有的没加缓动效果
            CameraKeyMove();
            CameraMiddleMove();
            CameraRotate();
            CameraScale();
        }

        //不同视角
        CameraMode();

        //相机复位
        if (Input.GetKeyUp(KeyCode.Space))
        {
            CameraReset();
        }


    }
    private void CameraMode()
    {
        switch (viewMode)
        {
            case CamViewMode.TOP:
                camTrans.localRotation = Quaternion.Euler(90, camTrans.localRotation.eulerAngles.y, camTrans.localRotation.eulerAngles.z);
                break;
            default:
                break;
        }
    }
    void CameraScale()
    {
        //鼠标滚轮场景缩放;
        if (Input.GetAxis("Mouse ScrollWheel") != 0)
        {
            float m_distance = Input.GetAxis("Mouse ScrollWheel") * m_sSpeed;
            Vector3 newPos = camTrans.localPosition + camTrans.forward * m_distance;
            Debug.Log(newPos.magnitude);
            if (newPos.magnitude >= m_maxDistance) return;
            camTrans.localPosition = newPos;
        }
    }
    void CameraRotate()
    {
        //鼠标右键点下控制相机旋转;
        if (Input.GetMouseButton(1))
        {
            if (!_isFirstClick)
            {
                m_deltX += Input.GetAxis("Mouse X") * m_rSpeed;
                m_deltY -= Input.GetAxis("Mouse Y") * m_rSpeed;
            }
            else//第一次点击时规划角度
            {
                _isFirstClick = false;
                m_deltX = _resetAngles.y;
                m_deltY = _resetAngles.x;
            }

            m_deltX = ClampAngle(m_deltX, -360, 360);
            m_deltY = ClampAngle(m_deltY, -70, 70);

            camTrans.localRotation = Quaternion.Euler(m_deltY, m_deltX, 0);
        }

    }
    void CameraKeyMove()
    {
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow))
        {
            camTrans.Translate(Vector3.forward * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow))
        {
            camTrans.Translate(Vector3.back * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow))
        {
            camTrans.Translate(Vector3.left * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow))
        {
            camTrans.Translate(Vector3.right * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.Q)) 
        {
            camTrans.Translate(Vector3.down * Time.deltaTime * m_speed);
        }
        if (Input.GetKey(KeyCode.E))
        {
            camTrans.Translate(Vector3.up * Time.deltaTime * m_speed);
        }
    }
    void CameraMiddleMove()
    {
        //点击鼠标中键控制移动;
        if (Input.GetMouseButton(2))
        {
            float dx = Input.GetAxis("Mouse X");
            float dy = Input.GetAxis("Mouse Y");
            Vector3 yz = camTrans.forward + camTrans.up;
            yz.y = 0;
            Vector3 TargetLookAt = camTrans.position;
            TargetLookAt -= (yz * dy + transform.right * dx) * m_mSpeed;
            camTrans.position = Vector3.Lerp(camTrans.position, TargetLookAt, moveSmoothing);
        }
    }
    public void CameraReset()
    {
        //相机位置和角度重置，需要自己设一个初始的位置和角度
        camTrans.localPosition = _resetTrans;
        camTrans.localRotation = Quaternion.Euler(_resetAngles);
    }
    //规划角度;
    float ClampAngle(float angle, float minAngle, float maxAgnle)
    {
        if (angle <= -360)
            angle += 360;
        if (angle >= 360)
            angle -= 360;

        return Mathf.Clamp(angle, minAngle, maxAgnle);
    }

}

